/// API 錯誤（非 2xx response），對齊 web `src/lib/errors.ts` 行為。
library;

/// 後端錯誤包裝；`code` 為穩定機器碼、`message` 為人話。
class ApiError implements Exception {
  const ApiError({
    required this.status,
    required this.code,
    required this.message,
    this.detail,
  });

  final int status;
  final String code;
  final String message;
  final String? detail;

  /// 三層 fallback：`{error:{code,message,detail}}` →
  /// `{error:"string"}`（OAuth flat，`error_description` 當 message）→
  /// status fallback。detail 截 200 字。
  factory ApiError.fromResponse(int status, dynamic body) {
    if (body is Map) {
      final errorField = body['error'];
      if (errorField is Map) {
        return ApiError(
          status: status,
          code: errorField['code']?.toString() ?? 'HTTP_$status',
          message: errorField['message']?.toString() ?? 'HTTP $status',
          detail: _truncateDetail(errorField['detail']?.toString()),
        );
      }
      if (errorField is String && errorField.isNotEmpty) {
        return ApiError(
          status: status,
          code: errorField,
          message: body['error_description']?.toString() ?? errorField,
        );
      }
    }
    return ApiError(
      status: status,
      code: 'HTTP_$status',
      message: 'HTTP $status',
    );
  }

  static String? _truncateDetail(String? rawDetail) {
    if (rawDetail == null) return null;
    return rawDetail.length <= 200 ? rawDetail : rawDetail.substring(0, 200);
  }

  @override
  String toString() =>
      'ApiError($status $code): $message${detail == null ? '' : ' — $detail'}';
}
