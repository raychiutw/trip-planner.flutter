/// Client-side error report payload accepted by `/reports`.
library;

class TripErrorReport {
  const TripErrorReport({
    required this.tripId,
    this.url,
    this.errorCode,
    this.errorMessage,
    this.userAgent,
    this.context,
    this.timestamp,
  });

  final String tripId;
  final String? url;
  final String? errorCode;
  final String? errorMessage;
  final String? userAgent;
  final String? context;
  final String? timestamp;

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    if (_hasText(url)) 'url': url!.trim(),
    if (_hasText(errorCode)) 'errorCode': errorCode!.trim(),
    if (_hasText(errorMessage)) 'errorMessage': errorMessage!.trim(),
    if (_hasText(userAgent)) 'userAgent': userAgent!.trim(),
    if (_hasText(context)) 'context': context!.trim(),
    if (_hasText(timestamp)) 'timestamp': timestamp!.trim(),
  };
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
