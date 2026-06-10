import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';

void main() {
  group('ApiError.fromResponse 三層 fallback', () {
    test('第一層：巢狀 {error:{code,message,detail}}', () {
      final apiError = ApiError.fromResponse(404, {
        'error': {
          'code': 'DATA_NOT_FOUND',
          'message': '找不到行程',
          'detail': 'trip okinawa-x 不存在',
        },
      });

      expect(apiError.status, 404);
      expect(apiError.code, 'DATA_NOT_FOUND');
      expect(apiError.message, '找不到行程');
      expect(apiError.detail, 'trip okinawa-x 不存在');
    });

    test('第一層：detail 超過 200 字截斷', () {
      final longDetail = 'x' * 500;
      final apiError = ApiError.fromResponse(500, {
        'error': {
          'code': 'SYS_INTERNAL',
          'message': '系統錯誤',
          'detail': longDetail,
        },
      });

      expect(apiError.detail, hasLength(200));
    });

    test('第二層：OAuth flat {error, error_description}', () {
      final apiError = ApiError.fromResponse(400, {
        'error': 'invalid_grant',
        'error_description': 'authorization code expired',
      });

      expect(apiError.code, 'invalid_grant');
      expect(apiError.message, 'authorization code expired');
      expect(apiError.detail, isNull);
    });

    test('第二層：flat error 無 error_description 時 message 沿用 code', () {
      final apiError = ApiError.fromResponse(403, {'error': 'Invalid origin'});

      expect(apiError.code, 'Invalid origin');
      expect(apiError.message, 'Invalid origin');
    });

    test('第三層：無法解析的 body 以 status fallback', () {
      final apiError = ApiError.fromResponse(502, '<html>Bad Gateway</html>');

      expect(apiError.status, 502);
      expect(apiError.code, 'HTTP_502');
      expect(apiError.message, 'HTTP 502');
    });

    test('第三層：null body 以 status fallback', () {
      final apiError = ApiError.fromResponse(500, null);

      expect(apiError.code, 'HTTP_500');
    });

    test('toString 含 status 與 code（debug 可讀）', () {
      final apiError = ApiError.fromResponse(401, {
        'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
      });

      expect(apiError.toString(), contains('401'));
      expect(apiError.toString(), contains('AUTH_REQUIRED'));
    });
  });
}
