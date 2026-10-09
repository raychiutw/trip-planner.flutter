import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/app/error_message.dart';

void main() {
  // 三層 fallback 的第一層守門:判錯的後果是 server 已經給的人話被吞掉,
  // 使用者只拿到一句通用訊息 —— 比不做翻譯還少資訊。
  group('userFacingApiError', () {
    test('絕不回傳後端 detail 原文', () {
      const error = ApiError(
        status: 400,
        code: 'INTERNAL',
        message: 'boom',
        detail: 'SQLITE_ERROR: no such column foo',
      );
      expect(userFacingApiError(error, fallback: '操作失敗，請稍後再試'), '操作失敗，請稍後再試');
    });

    test('code 對照表優先，其次繁中 message，再其次依 status，最後 fallback', () {
      const mapped = ApiError(status: 400, code: 'X', message: '中文訊息');
      expect(
        userFacingApiError(mapped, fallback: 'f', byCode: {'X': '對照表'}),
        '對照表',
      );
      expect(userFacingApiError(mapped, fallback: 'f'), '中文訊息');
      const rate = ApiError(status: 429, code: 'R', message: 'slow');
      expect(userFacingApiError(rate, fallback: 'f'), '操作太頻繁，請稍後再試');
      const other = ApiError(status: 418, code: 'T', message: 'teapot');
      expect(userFacingApiError(other, fallback: 'f'), 'f');
    });

    test('非 ApiError 一律 fallback', () {
      expect(userFacingApiError(Exception('x'), fallback: 'f'), 'f');
    });
  });

  group('hasCjk', () {
    test('繁中訊息回 true', () {
      expect(hasCjk('請求過於頻繁，請於 60 秒後再試'), isTrue);
      expect(hasCjk('你沒有這個行程的編輯權限'), isTrue);
      // 中英夾雜也算人話（後端常把欄位名留英文）
      expect(hasCjk('欄位 displayName 不可為空'), isTrue);
    });

    test('純英文與機器碼回 false', () {
      expect(hasCjk('ai generation rejected by upstream'), isFalse);
      expect(hasCjk('NOTES_AI_INVALID_OUTPUT'), isFalse);
      expect(hasCjk('HTTP 500'), isFalse);
      expect(hasCjk(''), isFalse);
    });

    test('全形標點與數字本身不算人話,只有漢字才算', () {
      // 只有標點的訊息不該被當成繁中而蓋掉 code 對照表的翻譯。
      expect(hasCjk('，。！？'), isFalse);
      expect(hasCjk('429'), isFalse);
    });
  });
}
