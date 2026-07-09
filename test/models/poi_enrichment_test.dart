import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_enrichment.dart';

void main() {
  group('PoiEnrichmentResult.fromJson', () {
    test('解析 enrich response snake_case 欄位', () {
      final result = PoiEnrichmentResult.fromJson({
        'poi_id': 42,
        'name': '暖暮拉麵',
        'place_id': 'ChIJ123',
        'status': 'active',
        'status_reason': '',
        'rating': '4.3',
        'refreshed_at': '2026-07-09T10:00:00Z',
      });

      expect(result.poiId, 42);
      expect(result.placeId, 'ChIJ123');
      expect(result.status, PoiEnrichmentStatus.active);
      expect(result.statusReason, isNull);
      expect(result.rating, 4.3);
      expect(result.refreshedAt, '2026-07-09T10:00:00Z');
    });

    test('狀態 fallback', () {
      expect(parsePoiEnrichmentStatus('closed'), PoiEnrichmentStatus.closed);
      expect(parsePoiEnrichmentStatus('missing'), PoiEnrichmentStatus.missing);
      expect(parsePoiEnrichmentStatus('archived'), PoiEnrichmentStatus.unknown);
    });
  });
}
