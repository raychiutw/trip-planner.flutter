/// 旅伴被 owner 缺同意擋下時的告知 alert。同意權仍在 owner 手上，旅伴只能
/// 把通知文字傳給他（A27 方案 B：複製這句話，不需後端）。
library;

import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

/// 標題對齊 web。
const _title = '暫時無法使用 AI 助理';
const _lead = '行程擁有者尚未同意 AI 資料處理，';

/// 旅伴傳給 owner 的那一句；路徑名稱要與帳號頁「AI 與資料」一致。
const kAiOwnerNotice = '我想用 Tripline 的 AI 排行程，請到 帳號設定 → AI 與資料 同意一下，謝謝！';

/// 「知道了」關閉；「複製這句話」開系統分享選單（可選拷貝、訊息等），alert 保持開著。
Future<void> showAiOwnerConsentMissingAlert(
  BuildContext context, {
  bool inputKept = false,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      key: const ValueKey('ai-data-consent-owner-missing'),
      title: const Text(_title),
      content: Column(
        children: [
          Text(
            '$_lead所以 AI 暫時無法處理你的要求。\n\n'
            '${inputKept ? '你的訊息已保留，沒有送出。' : '這次操作沒有執行。'}'
            '把下面這句傳給擁有者，請他到「帳號設定 → AI 與資料」同意：',
          ),
          const SizedBox(height: 8),
          const Text(kAiOwnerNotice),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: kAiOwnerNotice, title: '請擁有者同意 AI 資料處理'),
          ),
          child: const Text('複製這句話'),
        ),
      ],
    ),
  );
}
