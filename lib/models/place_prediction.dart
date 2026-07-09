/// Google Places autocomplete prediction returned by `/places/autocomplete`.
library;

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) =>
      PlacePrediction(
        placeId: _stringValue(json['placeId'] ?? json['place_id']),
        primaryText: _stringValue(json['primaryText'] ?? json['primary_text']),
        secondaryText: _stringValue(
          json['secondaryText'] ?? json['secondary_text'],
        ),
      );
}

String _stringValue(Object? value) => value?.toString() ?? '';
