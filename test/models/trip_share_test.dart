import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_share.dart';

void main() {
  test('TripShare.fromJson + isActive', () {
    final s = TripShare.fromJson(const {
      'id': 1,
      'label': '給爸媽',
      'visibleSections': ['flights', 'lodgings'],
      'expiresAt': null,
      'viewCount': 3,
      'anonymous': 1,
      'revokedAt': null,
    });
    expect(s.label, '給爸媽');
    expect(s.visibleSections, ['flights', 'lodgings']);
    expect(s.viewCount, 3);
    expect(s.anonymous, isTrue);
    expect(s.isActive, isTrue);
  });

  test('revoked → isActive false', () {
    final s = TripShare.fromJson(const {'id': 1, 'revokedAt': '2026-06-12'});
    expect(s.isRevoked, isTrue);
    expect(s.isActive, isFalse);
  });

  test('expired(過去 epoch ms)→ isActive false', () {
    final s = TripShare.fromJson({'id': 1, 'expiresAt': 1000});
    expect(s.isExpired, isTrue);
    expect(s.isActive, isFalse);
  });

  test('ShareLink.fullUrl = origin + url', () {
    final l = ShareLink.fromJson(const {
      'id': 5,
      'token': 'tok123',
      'url': '/s/tok123',
      'label': 'x',
    });
    expect(
      l.fullUrl('https://trip-planner-dby.pages.dev'),
      'https://trip-planner-dby.pages.dev/s/tok123',
    );
  });

  test('RotatedShareLink.fromJson + fullUrl', () {
    final l = RotatedShareLink.fromJson(const {
      'token': 'tok456',
      'url': '/s/tok456',
    });

    expect(l.token, 'tok456');
    expect(
      l.fullUrl('https://trip-planner-dby.pages.dev'),
      'https://trip-planner-dby.pages.dev/s/tok456',
    );
  });
}
