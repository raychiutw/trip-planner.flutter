import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_glass_surface.dart';
import 'map_adapter.dart';

abstract interface class TripMapLocationService {
  Future<TripMapPoint> currentLocation();
}

/// 系統設定中可恢復的定位設定目標。
enum TripMapLocationSettingsTarget { application, locationService }

class TripMapLocationException implements Exception {
  const TripMapLocationException(this.message, {this.settingsTarget});

  final String message;
  final TripMapLocationSettingsTarget? settingsTarget;

  @override
  String toString() => message;
}

class GeolocatorTripMapLocationService implements TripMapLocationService {
  const GeolocatorTripMapLocationService();

  @override
  Future<TripMapPoint> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const TripMapLocationException(
        '定位服務未開啟，請前往「設定」開啟定位服務',
        settingsTarget: TripMapLocationSettingsTarget.locationService,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw const TripMapLocationException(
        '定位權限遭拒或受限制，請前往「設定」允許定位',
        settingsTarget: TripMapLocationSettingsTarget.application,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return TripMapPoint(position.latitude, position.longitude);
  }
}

/// 開啟可恢復定位權限或服務的系統設定頁。
Future<bool> openTripMapLocationSettings(
  TripMapLocationSettingsTarget target,
) => switch (target) {
  TripMapLocationSettingsTarget.application => Geolocator.openAppSettings(),
  TripMapLocationSettingsTarget.locationService =>
    Geolocator.openLocationSettings(),
};

class TripMapLocateButton extends StatelessWidget {
  const TripMapLocateButton({
    super.key,
    required this.locating,
    required this.onPressed,
  });

  final bool locating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const tooltip = '定位目前位置';
    final onMedia = TpMediaBackdropScope.of(context);
    final foreground = tpBarForeground(context, onMedia: onMedia);
    final settings = onMedia
        ? tpMediaIconGlassSettings(context)
        : tpNavigationGlassSettings(context);
    if (locating) {
      // 套件 disabled 會淡化整片玻璃；進度改用同一共用表面，
      // 讓無障礙不透明底不受影響，且此狀態沒有可觸發的回呼。
      return Semantics(
        label: tooltip,
        button: true,
        enabled: false,
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: TpGlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(TpRadius.sm)),
            platformViewBackdrop: onMedia,
            glassSettings: settings,
            tintColor: Theme.of(context).colorScheme.surface,
            child: SizedBox.square(
              dimension: TpSpacing.tapMin,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return TpToolbarGlassButton(
      tooltip: tooltip,
      onPressed: onPressed,
      borderRadius: TpRadius.sm,
      platformViewBackdrop: onMedia,
      glassSettings: settings,
      child: Icon(Icons.my_location, color: foreground),
    );
  }
}

TripMapMarker buildTripMapUserLocationMarker({
  required TripMapPoint point,
  required String id,
}) {
  return TripMapMarker(
    id: id,
    point: point,
    color: const Color(0xFF2563EB),
    title: '目前位置',
    zIndex: 1000,
    clusterable: false,
  );
}
