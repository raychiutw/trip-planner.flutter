/// AI 行程助手畫面:頂端行程下拉(預設最近)+ 工單佇列聊天串
/// (三方氣泡 / markdown + deep-link / 樂觀送出 / 上捲分頁)。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../trips/trips_list_screen.dart';
import 'chat_controller.dart';
import 'chat_link.dart';
import 'chat_message.dart';
import 'speech_service.dart';

/// 空對話時顯示的 4 個示範建議 prompt。
const List<String> _suggestedPrompts = [
  '幫我規劃 Day 1 的早午餐',
  '推薦附近 30 分鐘車程內的景點',
  '把第二天的午餐改成沖繩麵',
  '加入適合親子的水族館行程',
];

/// chat composer 的 iMessage 風格圓角膠囊外框(無邊、各狀態一致)。
const _composerPillBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(20)),
  borderSide: BorderSide.none,
);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _tripId;

  /// 下拉顯示名:title 優先,空值退回 name。
  String _tripLabel(TripSummary t) {
    final title = t.title?.trim();
    return (title == null || title.isEmpty) ? t.name : title;
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: tripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) =>
            const _CenteredHint(title: '載入失敗', body: '無法取得行程清單,請稍後再試。'),
        data: (trips) {
          if (trips.isEmpty) {
            return const _CenteredHint(
              title: '先建立行程',
              body: '建立行程後,就能在這裡用 AI 助手調整行程。',
            );
          }
          // 預設最近(清單第一筆);使用者可下拉切換。_tripId 可能指向已不存在
          // 的行程(清單刷新後)→ 退回最近一筆,避免 Dropdown value 不在 items 的 assert。
          final tripId = trips.any((t) => t.tripId == _tripId)
              ? _tripId!
              : trips.first.tripId;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TpSpacing.s4,
                  TpSpacing.s3,
                  TpSpacing.s4,
                  TpSpacing.s2,
                ),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('chat-trip-dropdown'),
                  initialValue: tripId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '行程',
                    isDense: true,
                  ),
                  items: [
                    for (final t in trips)
                      DropdownMenuItem(
                        value: t.tripId,
                        child: Text(
                          _tripLabel(t),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tripId = v);
                  },
                ),
              ),
              Expanded(
                child: _ChatBody(key: ValueKey(tripId), tripId: tripId),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 單一行程的聊天串(訊息清單 + 輸入列)。
class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final _scroll = ScrollController();
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // reverse list:接近「頂端」= 接近 maxScrollExtent → 載入更舊。
  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      unawaited(
        ref.read(chatControllerProvider(widget.tripId).notifier).loadOlder(),
      );
    }
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    HapticFeedback.lightImpact();
    unawaited(
      ref.read(chatControllerProvider(widget.tripId).notifier).send(text),
    );
    // 捲到底(reverse list 底部 = offset 0)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.tripId));
    final myEmail = switch (ref.watch(authStateProvider)) {
      AsyncData(:final value) => value?.email,
      _ => null,
    };
    final msgs = state.messages;

    final controller = ref.read(chatControllerProvider(widget.tripId).notifier);

    return Column(
      children: [
        if (state.authExpired) const _Banner(text: '登入已過期,請重新登入後再試。'),
        // 有訊息時錯誤走非阻擋橫幅;空清單(初次載入失敗)走置中錯誤 + 重試。
        if (state.error != null && msgs.isNotEmpty) _Banner(text: state.error!),
        Expanded(
          child: state.initialLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : (state.error != null && msgs.isEmpty)
              ? _CenteredHint(
                  title: '載入失敗',
                  body: '無法取得對話,請稍後再試。',
                  onRetry: () => unawaited(controller.reload()),
                )
              : msgs.isEmpty
              ? _EmptyStatePrompts(
                  sending: state.sending,
                  onSelect: (prompt) => unawaited(controller.send(prompt)),
                )
              : ListView.builder(
                  key: const ValueKey('chat-list'),
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(TpSpacing.s4),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[msgs.length - 1 - i];
                    return _MessageBubble(
                      message: m,
                      tripId: widget.tripId,
                      myEmail: myEmail,
                    );
                  },
                ),
        ),
        _Composer(input: _input, sending: state.sending, onSend: _send),
      ],
    );
  }
}

/// 三方氣泡:自己(accent,右)/ 協作者(pink,左+名字)/ AI(sage,左+「Tripline AI」)。
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.tripId,
    required this.myEmail,
  });

  final ChatMessage message;
  final String tripId;
  final String? myEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = theme.extension<TpTones>()!;

    final isAssistant = message.role == ChatRole.assistant;
    // submittedBy 為空(樂觀 temp / 認證未解析)視為自己。
    final isSelf =
        !isAssistant &&
        (message.submittedBy == null || message.submittedBy == myEmail);

    final Color bg;
    if (message.isFailed) {
      bg = scheme.errorContainer;
    } else if (isAssistant) {
      bg = tones.sageSubtle;
    } else if (isSelf) {
      bg = tones.accentSubtle;
    } else {
      bg = tones.pinkSubtle;
    }
    final textColor = message.isFailed
        ? scheme.onErrorContainer
        : scheme.onSurface;

    String? label;
    Color? labelColor;
    if (isAssistant) {
      label = 'Tripline AI';
      labelColor = tones.sageDeep;
    } else if (!isSelf) {
      label = message.senderName ?? '協作者';
      labelColor = tones.pinkDeep;
    }

    final Widget content;
    if (message.pendingRequestId != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: TpSpacing.s2),
          Text(message.text),
        ],
      );
    } else if (isAssistant && message.isMarkdown) {
      content = MarkdownBody(
        data: message.text,
        onTapLink: (text, href, title) {
          final loc = mapReplyLink(href ?? '', tripId);
          if (loc != null) context.push(loc);
        },
      );
    } else {
      content = Text(message.text);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s1),
      child: Column(
        crossAxisAlignment: isSelf
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(
                left: TpSpacing.s1,
                right: TpSpacing.s1,
                bottom: 2,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s3,
                vertical: TpSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(TpRadius.lg),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: textColor),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 輸入列:多行 TextField + 語音鈕 + 送出鈕(送出中顯示 spinner)。
/// 語音鈕 lazy:進頁不請求權限;點擊時才 init SpeechService(請求麥克風/語音
/// 辨識權限)→ 成功則 listen,辨識文字回填輸入框;init 失敗(權限拒絕/不支援)
/// → SnackBar 提示且不 listen。聆聽中切換 icon/配色,再點則 stop。
class _Composer extends ConsumerStatefulWidget {
  const _Composer({
    required this.input,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController input;
  final bool sending;
  final VoidCallback onSend;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  /// null = 尚未初始化過;true/false = 最近一次 init 結果(快取,避免重複請求)。
  bool? _speechAvailable;
  bool _listening = false;

  /// lazy init:第一次成功後快取結果,後續沿用不再請求權限。
  Future<bool> _ensureInit() async {
    if (_speechAvailable == true) return true;
    final ok = await ref.read(speechServiceProvider).init();
    if (mounted) setState(() => _speechAvailable = ok);
    return ok;
  }

  /// 點麥克風鈕:聆聽中 → stop;否則 lazy init,成功才 listen,失敗則提示。
  Future<void> _onMic() async {
    final speech = ref.read(speechServiceProvider);
    if (_listening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _ensureInit();
    if (!mounted) return;
    if (!ok) {
      showAppNotice(context, '需要麥克風與語音辨識權限才能語音輸入');
      return;
    }
    setState(() => _listening = true);
    await speech.listen((text) {
      if (!mounted) return;
      widget.input.text = text;
      widget.input.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // lazy:預設 enabled,僅送出中 disable;權限在點擊時才檢查。
    final micEnabled = !widget.sending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TpSpacing.s3,
          TpSpacing.s2,
          TpSpacing.s3,
          TpSpacing.s2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: widget.input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSend(),
                // iMessage 風格:圓角膠囊 + subtle 填色,無硬框(各狀態一致)。
                decoration: InputDecoration(
                  hintText: '輸入訊息或語音指令',
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: TpSpacing.s4,
                    vertical: TpSpacing.s3,
                  ),
                  border: _composerPillBorder,
                  enabledBorder: _composerPillBorder,
                  focusedBorder: _composerPillBorder,
                ),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton(
              key: const ValueKey('chat-mic-button'),
              tooltip: _listening ? '停止語音輸入' : '語音輸入',
              onPressed: micEnabled ? () => unawaited(_onMic()) : null,
              color: _listening ? scheme.primary : null,
              icon: Icon(
                _listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
              ),
            ),
            const SizedBox(width: TpSpacing.s1),
            IconButton.filled(
              key: const ValueKey('chat-send'),
              onPressed: widget.sending ? null : widget.onSend,
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.arrow_up_circle_fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空對話引導:標題 + 說明 + 4 個建議 prompt 快捷鈕。
class _EmptyStatePrompts extends StatelessWidget {
  const _EmptyStatePrompts({required this.sending, required this.onSelect});

  final bool sending;
  final void Function(String prompt) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('從一個指令開始', style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '選一個建議,或直接在下方輸入你想調整的行程。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _suggestedPrompts.length; i++)
                  ActionChip(
                    key: ValueKey('chat-suggestion-$i'),
                    label: Text(_suggestedPrompts[i]),
                    onPressed: sending
                        ? null
                        : () => onSelect(_suggestedPrompts[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 置中提示(空清單 / 空對話 / 錯誤)。
class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.title, required this.body, this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TpSpacing.s4),
              FilledButton(
                key: const ValueKey('chat-retry'),
                onPressed: onRetry,
                child: const Text('重試'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 頂端橫幅(authExpired / error)。
class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: scheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
