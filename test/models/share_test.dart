import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/share.dart';

void main() {
  test('TripShareLink.fromJson 解析分享連結 row 與 visibleSections allowlist', () {
    final link = TripShareLink.fromJson({
      'id': 7,
      'label': '給爸媽',
      'visibleSections': '["flights","lodgings","unknown","pretrip"]',
      'expiresAt': 1893456000000,
      'viewCount': 3,
      'anonymous': 1,
      'createdBy': 'user-1',
      'createdAt': '2026-07-08T10:00:00Z',
      'revokedAt': null,
    });

    expect(link.id, 7);
    expect(link.label, '給爸媽');
    expect(link.visibleSectionKeys, ['flights', 'lodgings', 'pretrip']);
    expect(link.expiresAt, 1893456000000);
    expect(link.viewCount, 3);
    expect(link.isAnonymous, isTrue);
    expect(link.isRevoked, isFalse);
  });

  test('TripShareLink.fromJson 支援 snake_case fallback 與 revoked 判斷', () {
    final link = TripShareLink.fromJson({
      'id': 8,
      'visible_sections': '["emergency"]',
      'view_count': 12,
      'created_at': '2026-07-08T10:00:00Z',
      'revoked_at': '2026-07-09T10:00:00Z',
    });

    expect(link.visibleSectionKeys, ['emergency']);
    expect(link.viewCount, 12);
    expect(link.isRevoked, isTrue);
  });

  test('CreatedTripShare.fromJson 解析一次性 token/url', () {
    final created = CreatedTripShare.fromJson({
      'id': 9,
      'token': 'raw-token',
      'url': '/s/raw-token',
      'label': '旅伴',
      'visibleSections': ['flights', 'pretrip'],
      'expiresAt': null,
      'anonymous': true,
    });

    expect(created.id, 9);
    expect(created.token, 'raw-token');
    expect(created.url, '/s/raw-token');
    expect(created.visibleSections, ['flights', 'pretrip']);
    expect(created.isAnonymous, isTrue);
  });

  test('PublicTripShare.fromJson 解析公開分享 payload 與 meta fallback', () {
    final share = PublicTripShare.fromJson({
      'meta': {
        'name': 'okinawa-trip-2026',
        'title': '沖繩家族旅行',
        'countries': 'JP',
        'sharedBy': 'Ray',
        'destinations': [
          {'name': '那霸'},
          {'name': '名護'},
        ],
      },
      'days': [
        {
          'id': 10,
          'dayNum': 1,
          'date': '2026-10-01',
          'dayOfWeek': '四',
          'label': '抵達日',
          'version': 1,
          'timeline': [
            {
              'id': 101,
              'sortOrder': 0,
              'displayTitle': '首里城公園',
              'version': 1,
              'startTime': '09:00',
              'endTime': '10:30',
            },
          ],
        },
      ],
      'notes': {
        'flights': [
          {'id': 1, 'sortOrder': 0, 'flightNo': 'BR112'},
        ],
        'lodgings': [],
        'reservations': [],
        'pretripNotes': [],
        'emergencyContacts': [],
      },
    });

    expect(share.displayTitle, '沖繩家族旅行');
    expect(share.sharedBy, 'Ray');
    expect(share.destinationsLabel, '那霸 · 名護');
    expect(share.dateRange, '2026-10-01');
    expect(share.days.single.timeline.single.title, '首里城公園');
    expect(share.notes.flights.single.flightNo, 'BR112');
  });
}
