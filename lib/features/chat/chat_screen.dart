/// AI 行程助手畫面:頂端行程下拉(預設最近)+ 工單佇列聊天串
/// (三方氣泡 / markdown + deep-link / 樂觀送出 / 上捲分頁)。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../trips/trips_list_screen.dart';
import 'chat_controller.dart';
import 'chat_link.dart';
import 'chat_message.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const _CenteredHint(
          title: '載入失敗',
          body: '無法取得行程清單,請稍後再試。',
        ),
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
                    TpSpacing.s4, TpSpacing.s3, TpSpacing.s4, TpSpacing.s2),
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
                        child: Text(_tripLabel(t), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tripId = v);
                  },
                ),
              ),
              Expanded(child: _ChatBody(key: ValueKey(tripId), tripId: tripId)),
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
          ref.read(chatControllerProvider(widget.tripId).notifier).loadOlder());
    }
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    unawaited(
        ref.read(chatControllerProvider(widget.tripId).notifier).send(text));
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

    return Column(
      children: [
        if (state.authExpired) const _Banner(text: '登入已過期,請重新登入後再試。'),
        if (state.error != null) _Banner(text: state.error!),
        Expanded(
          child: state.initialLoading
              ? const Center(child: CircularProgressIndicator())
              : msgs.isEmpty
                  ? const _CenteredHint(
                      title: '開始跟 AI 對話',
                      body: '例如:「幫我把第二天下午改成室內行程」。',
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
    final isSelf = !isAssistant &&
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
    final textColor =
        message.isFailed ? scheme.onErrorContainer : scheme.onSurface;

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
            child: CircularProgressIndicator(strokeWidth: 2),
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
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(
                  left: TpSpacing.s1, right: TpSpacing.s1, bottom: 2),
              child: Text(
                label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: labelColor, fontWeight: FontWeight.w600),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s3, vertical: TpSpacing.s2),
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

/// 輸入列:多行 TextField + 送出鈕(送出中顯示 spinner)。
class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController input;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            TpSpacing.s3, TpSpacing.s2, TpSpacing.s3, TpSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '輸入訊息…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filled(
              key: const ValueKey('chat-send'),
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// 置中提示(空清單 / 空對話 / 錯誤)。
class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.title, required this.body});

  final String title;
  final String body;

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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
