import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/trip_map_cluster_projector.dart';

void main() {
  test('nearby clusterable markers share a stable cluster at zoom 12', () {
    final result = const TripMapClusterProjector().project(
      markers: [
        _markerAt('a', 25.0330, 121.5650),
        _markerAt('b', 25.0332, 121.5652),
      ],
      zoom: 12,
    );

    expect(result.single.memberIds, ['a', 'b']);
    expect(result.single.glyph, '2');
  });

  test('non-clusterable user marker is never absorbed', () {
    final result = const TripMapClusterProjector().project(
      markers: [
        _markerAt('poi', 25, 121),
        _markerAt('user', 25, 121, clusterable: false),
      ],
      zoom: 12,
    );

    expect(
      result.where((item) => item.memberIds.contains('user')).single.isCluster,
      isFalse,
    );
  });

  test('zooming in separates markers without changing semantic IDs', () {
    const projector = TripMapClusterProjector();
    final denseMarkers = [
      _markerAt('a', 25.0330, 121.5650),
      _markerAt('b', 25.0332, 121.5652),
      _markerAt('c', 25.0334, 121.5654),
    ];

    final clustered = projector.project(markers: denseMarkers, zoom: 12);
    final separated = projector.project(markers: denseMarkers, zoom: 17);

    expect(clustered.length, lessThan(separated.length));
    expect(
      separated.expand((item) => item.memberIds).toSet(),
      denseMarkers.map((item) => item.id).toSet(),
    );
  });
}

TripMapMarker _markerAt(
  String id,
  double latitude,
  double longitude, {
  bool clusterable = true,
}) => TripMapMarker(
  id: id,
  point: TripMapPoint(latitude, longitude),
  color: Colors.blue,
  clusterable: clusterable,
  glyph: '1',
);
