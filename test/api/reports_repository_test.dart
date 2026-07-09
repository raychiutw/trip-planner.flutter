import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/reports_repository.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/models/error_report.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late ReportsRepository reportsRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    reportsRepository = ReportsRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('submitErrorReport：POST /reports with trip error body', () async {
    dioAdapter.onPost(
      '/reports',
      (server) => server.reply(201, {'ok': true}),
      data: {
        'tripId': 'trip-1',
        'url': '/trip/trip-1',
        'errorCode': 'SYS_INTERNAL',
        'errorMessage': 'Something failed',
        'userAgent': 'Flutter test',
        'context': '{"severity":"error"}',
      },
    );

    await reportsRepository.submitErrorReport(
      const TripErrorReport(
        tripId: 'trip-1',
        url: '/trip/trip-1',
        errorCode: 'SYS_INTERNAL',
        errorMessage: 'Something failed',
        userAgent: 'Flutter test',
        context: '{"severity":"error"}',
      ),
    );
  });
}
