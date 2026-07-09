import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/place_prediction.dart';

void main() {
  group('PlacePrediction.fromJson', () {
    test('解析 autocomplete camelCase 欄位', () {
      final prediction = PlacePrediction.fromJson({
        'placeId': 'ChIJ123',
        'primaryText': '高雄市左營區',
        'secondaryText': 'Kaohsiung City, Taiwan',
      });

      expect(prediction.placeId, 'ChIJ123');
      expect(prediction.primaryText, '高雄市左營區');
      expect(prediction.secondaryText, 'Kaohsiung City, Taiwan');
    });

    test('相容 snake_case fallback', () {
      final prediction = PlacePrediction.fromJson({
        'place_id': 'ChIJ456',
        'primary_text': '首里城',
        'secondary_text': 'Okinawa, Japan',
      });

      expect(prediction.placeId, 'ChIJ456');
      expect(prediction.primaryText, '首里城');
      expect(prediction.secondaryText, 'Okinawa, Japan');
    });
  });
}
