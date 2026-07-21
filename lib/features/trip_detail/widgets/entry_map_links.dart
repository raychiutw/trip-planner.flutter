import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/entry.dart';
import '../../../theme/tokens.dart';
import '../../map/google_maps_external_launcher.dart';

typedef EntryMapUrlLaunch = Future<bool> Function(Uri uri, {LaunchMode mode});

class EntryMapLinks extends StatelessWidget {
  const EntryMapLinks({
    super.key,
    required this.poi,
    required this.onError,
    this.launch = launchUrl,
  });

  final EntryPoiInfo poi;
  final VoidCallback onError;
  final EntryMapUrlLaunch launch;

  bool get _hasLocation =>
      (poi.lat != null && poi.lng != null) ||
      (poi.name?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_hasLocation) {
      return Semantics(label: '尚無位置', child: const SizedBox.shrink());
    }
    final platform = Theme.of(context).platform;
    final showApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return Wrap(
      key: ValueKey('entry-map-links-${poi.poiId}'),
      spacing: TpSpacing.s2,
      runSpacing: TpSpacing.s1,
      children: [
        _MapLinkButton(
          key: ValueKey('entry-google-map-${poi.poiId}'),
          label: 'Google',
          semanticLabel: '使用 Google 開啟地圖',
          onPressed: () => _openGoogle(),
        ),
        if (showApple)
          _MapLinkButton(
            key: ValueKey('entry-apple-map-${poi.poiId}'),
            label: 'Apple',
            semanticLabel: '使用 Apple 開啟地圖',
            onPressed: () => _openApple(),
          ),
      ],
    );
  }

  Future<void> _openGoogle() async {
    final uri = GoogleMapsExternalLauncher.buildEntryUri(
      name: poi.name,
      latitude: poi.lat,
      longitude: poi.lng,
    );
    if (!await _tryLaunch(uri, LaunchMode.externalApplication)) onError();
  }

  Future<void> _openApple() async {
    final coordinates = poi.lat == null || poi.lng == null
        ? null
        : '${poi.lat},${poi.lng}';
    final uri = Uri.https('maps.apple.com', '/', {
      if (poi.name?.trim().isNotEmpty ?? false) 'q': poi.name!.trim(),
      'll': ?coordinates,
    });
    if (await _tryLaunch(uri, LaunchMode.externalApplication)) return;
    if (!await _tryLaunch(uri, LaunchMode.platformDefault)) onError();
  }

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launch(uri, mode: mode);
    } on Exception {
      return false;
    }
  }
}

class _MapLinkButton extends StatelessWidget {
  const _MapLinkButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
      child: Semantics(
        label: semanticLabel,
        button: true,
        onTap: onPressed,
        excludeSemantics: true,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, TpSpacing.tapMin),
          ),
          onPressed: onPressed,
          icon: const Icon(CupertinoIcons.location_solid, size: 15),
          label: Text(label),
        ),
      ),
    );
  }
}
