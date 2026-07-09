import '../models/error_report.dart';
import 'api_client.dart';

class ReportsRepository {
  ReportsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// POST /reports → stores a client-side trip error report.
  Future<void> submitErrorReport(TripErrorReport report) =>
      _client.post('/reports', body: report.toJson());
}
