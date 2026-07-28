/// AI 行程助手畫面:頂端行程下拉(預設最近)+ 工單佇列聊天串
/// (三方氣泡 / markdown + deep-link / 樂觀送出 / 上捲分頁)。
library;

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_glass_surface.dart';
import '../../ui/tp_root_scaffold.dart';
import '../trips/current_trip_provider.dart';
import '../trips/trip_title_button.dart';
import '../trips/trips_list_screen.dart';
import 'ai_consent_sheet.dart';
import '../../models/trip_request.dart';
import 'chat_controller.dart';
import 'chat_link.dart';
import 'chat_message.dart';
import 'speech_service.dart';

/// 可替換的附件選擇器；測試可注入失敗，不直接觸發 platform channel。
typedef ChatAttachmentPicker = Future<XFile?> Function();

/// 聊天附件入口使用的系統檔案選擇器。
final chatAttachmentPickerProvider = Provider<ChatAttachmentPicker>(
  (ref) => openFile,
);

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
  const ChatScreen({super.key, this.initialTripId, this.initialPrefill});

  final String? initialTripId;
  final String? initialPrefill;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _pendingPrefill;
  String? _pendingRouteTripId;
  String? _renderedTripId;
  final _drafts = <String, String>{};
  bool? _speechAvailable;
  bool _speechPurposeAccepted = false;

  @override
  void initState() {
    super.initState();
    _pendingPrefill = widget.initialPrefill;
    final tripId = widget.initialTripId;
    _pendingRouteTripId = tripId;
    if (tripId != null) _selectRouteTripAfterBuild(tripId);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTripId != oldWidget.initialTripId) {
      _pendingRouteTripId = widget.initialTripId;
      if (widget.initialTripId != null) {
        _selectRouteTripAfterBuild(widget.initialTripId!);
      }
    }
    if (widget.initialPrefill != oldWidget.initialPrefill ||
        (widget.initialTripId != oldWidget.initialTripId &&
            widget.initialPrefill != null)) {
      _pendingPrefill = widget.initialPrefill;
    }
  }

  void _selectRouteTripAfterBuild(String tripId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRouteTripId != tripId) return;
      unawaited(ref.read(currentTripIdProvider.notifier).select(tripId));
      setState(() => _pendingRouteTripId = null);
    });
  }

  void _consumePrefill() {
    if (_pendingPrefill == null || !mounted) return;
    setState(() => _pendingPrefill = null);
  }

  void _setSpeechAvailable(bool? value) {
    if (_speechAvailable == value || !mounted) return;
    setState(() => _speechAvailable = value);
  }

  void _acceptSpeechPurpose() {
    if (_speechPurposeAccepted || !mounted) return;
    setState(() => _speechPurposeAccepted = true);
  }

  @override
  Widget build(BuildContext context) {
    Widget initiallyBelowHeader(Widget child) => Padding(
      padding: EdgeInsets.only(top: TpRootGeometry.initialContentTop(context)),
      child: child,
    );

    final tripsAsync = ref.watch(myTripsProvider);
    final trips = tripsAsync.value ?? const <TripSummary>[];
    final isActiveBranch = TickerMode.valuesOf(context).enabled;
    final selectedAsync = isActiveBranch
        ? ref.watch(currentTripIdProvider)
        : ref.read(currentTripIdProvider);
    if (isActiveBranch &&
        _pendingRouteTripId == null &&
        !selectedAsync.isLoading) {
      _renderedTripId = selectedAsync.value;
    }
    final selectedTripId =
        _pendingRouteTripId ??
        (isActiveBranch ? selectedAsync.value : _renderedTripId);
    final currentTrip = resolveCurrentTrip(trips, selectedTripId);
    final tripId = currentTrip?.tripId;
    final selectedTrip = trips
        .where((trip) => trip.tripId == selectedAsync.value)
        .firstOrNull;
    if (isActiveBranch &&
        _pendingRouteTripId == null &&
        widget.initialTripId != null &&
        selectedTrip != null &&
        widget.initialTripId != selectedTrip.tripId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          GoRouter.maybeOf(context)?.go(
            '/chat?tripId=${Uri.encodeQueryComponent(selectedTrip.tripId)}',
          );
        }
      });
    }

    return TpRootScaffold(
      header: TpRootHeaderConfig(
        title: currentTrip == null
            ? Text(tripsAsync.isLoading || tripsAsync.hasError ? '行程' : '尚無行程')
            : TripTitleButton(
                key: const ValueKey('chat-trip-dropdown'),
                currentTripId: currentTrip.tripId,
                currentTitle: currentTrip.title?.trim().isNotEmpty ?? false
                    ? currentTrip.title!.trim()
                    : currentTrip.name,
                trips: trips,
                onSelected: (value) => unawaited(
                  ref.read(currentTripIdProvider.notifier).select(value),
                ),
              ),
        actions: const [],
      ),
      body: tripsAsync.when(
        loading: () => initiallyBelowHeader(
          const Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) => initiallyBelowHeader(
          const _CenteredHint(title: '載入失敗', body: '無法取得行程清單,請稍後再試。'),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return initiallyBelowHeader(
              _CenteredHint(
                title: '尚無行程',
                body: '建立行程後,就能在這裡用 AI 助手調整行程。',
                actionLabel: '新增行程',
                onAction: () => context.push('/new-trip'),
              ),
            );
          }
          if ((selectedAsync.isLoading && _pendingRouteTripId == null) ||
              (_pendingRouteTripId != null && tripId != _pendingRouteTripId)) {
            return initiallyBelowHeader(
              const Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final pendingPrefill =
              _pendingPrefill != null &&
                  (widget.initialTripId == null ||
                      widget.initialTripId == tripId)
              ? _pendingPrefill
              : null;
          return _ChatBody(
            key: ValueKey(tripId),
            tripId: tripId!,
            initialPrefill: pendingPrefill ?? _drafts[tripId],
            onInitialPrefillConsumed: _consumePrefill,
            onDraftChanged: (draft) => _drafts[tripId] = draft,
            speechAvailable: _speechAvailable,
            speechPurposeAccepted: _speechPurposeAccepted,
            onSpeechAvailableChanged: _setSpeechAvailable,
            onSpeechPurposeAccepted: _acceptSpeechPurpose,
          );
        },
      ),
    );
  }
}

/// 單一行程的聊天串(訊息清單 + 輸入列)。
class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({
    super.key,
    required this.tripId,
    required this.onInitialPrefillConsumed,
    required this.onDraftChanged,
    required this.speechAvailable,
    required this.speechPurposeAccepted,
    required this.onSpeechAvailableChanged,
    required this.onSpeechPurposeAccepted,
    this.initialPrefill,
  });

  final String tripId;
  final String? initialPrefill;
  final VoidCallback onInitialPrefillConsumed;
  final ValueChanged<String> onDraftChanged;
  final bool? speechAvailable;
  final bool speechPurposeAccepted;
  final ValueChanged<bool?> onSpeechAvailableChanged;
  final VoidCallback onSpeechPurposeAccepted;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  /// 距最舊那一端多近就自動載入更舊(iMessage／LINE 的作法,不需手勢)。
  static const _loadOlderTrigger = 240.0;

  /// 視為「停在最新那一端」的容差。
  static const _latestEdgeSlop = 24.0;

  final _scroll = ScrollController();
  final _composerKey = GlobalKey();
  late final TextEditingController _input;
  late final Future<void> _aiAuthorizationLoad;
  ValueNotifier<int>? _reselects;
  bool _active = true;
  bool? _aiAuthorized;
  bool _sendInProgress = false;
  double _composerHeight = 0;

  /// 使用者按過「停止等待」但伺服器沒確認的那幾筆。伺服器那邊還是 processing,
  /// 靠這個把畫面推進到終結態 —— 後端的兜底機制之後會自己追上。
  final _locallyStopped = <int>{};

  /// 目前是否停在最新那一端;同時決定箭頭要不要出現,以及重拉的邊緣觸發。
  bool _atLatest = true;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialPrefill);
    _input.addListener(_saveDraft);
    _saveDraft();
    _scroll.addListener(_onScroll);
    _aiAuthorizationLoad = _loadAiAuthorization();
    unawaited(_aiAuthorizationLoad);
    if (widget.initialPrefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInitialPrefillConsumed();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ChatBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prefill = widget.initialPrefill;
    if (prefill == null || prefill == oldWidget.initialPrefill) return;
    _input.value = TextEditingValue(
      text: prefill,
      selection: TextSelection.collapsed(offset: prefill.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInitialPrefillConsumed();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    final next = TpRootReselectScope.maybeOf(context);
    if (next == _reselects) return;
    _reselects?.removeListener(_scrollToTop);
    _reselects = next?..addListener(_scrollToTop);
  }

  @override
  void dispose() {
    _reselects?.removeListener(_scrollToTop);
    _scroll.dispose();
    _input.removeListener(_saveDraft);
    _input.dispose();
    super.dispose();
  }

  void _saveDraft() => widget.onDraftChanged(_input.text);

  // reverse list:視覺底部 = 最新 = offset 0,視覺頂部 = 最舊 = maxScrollExtent。
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final controller = ref.read(chatControllerProvider(widget.tripId).notifier);
    if (position.pixels >= position.maxScrollExtent - _loadOlderTrigger) {
      unawaited(controller.loadOlder());
    }
    final atLatest = position.pixels <= _latestEdgeSlop;
    // 邊緣觸發:只有「從離開狀態回到最新那一端」的那一次才重拉。回程會連續經過
    // 多個貼近底部的位置,停在底部也還會有零星通知,靠 _atLatest 閂鎖擋掉重複。
    if (atLatest == _atLatest) return;
    if (atLatest) unawaited(controller.refreshLatest());
    setState(() => _atLatest = atLatest);
  }

  /// 停止等待 —— **不中止 AI**(後端 `raychiutw/trip-planner` 的 `docs/adr/0007`:不追殺 worker)。
  ///
  /// 標不掉也照樣把畫面換成終結態(與 web 一致),但**文案不能假裝成功** ——
  /// 伺服器沒確認就是沒確認,後端另有兜底機制會補上。
  Future<void> _stopWaiting(int id) async {
    var confirmed = true;
    try {
      await ref.read(requestsRepositoryProvider).stopWaiting(id);
    } on Object {
      confirmed = false;
    }
    if (!mounted) return;
    // 標不掉的時候伺服器那筆**沒有變**,重抓只會拿回同一個 processing ——
    // 所以本地先記下來,否則畫面會留在「思考中…」,使用者等於沒有出口。
    setState(() => _locallyStopped.add(id));
    await ref.read(chatControllerProvider(widget.tripId).notifier).reload();
    if (!mounted || confirmed) return;
    showAppError(context, '已停止等待，但伺服器沒有確認。它可能仍在處理。');
  }

  /// 回到最新訊息那一端(reverse list 底部 = offset 0);重拉由 [_onScroll] 接手。
  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
      return;
    }
    unawaited(
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  void _scrollToTop() {
    if (!_active || !_scroll.hasClients) return;
    final top = _scroll.position.maxScrollExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(top);
      return;
    }
    unawaited(
      _scroll.animateTo(
        top,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  void _syncComposerHeight() {
    if (!mounted) return;
    final box = _composerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final height = box.size.height;
    if ((height - _composerHeight).abs() < 0.5) return;
    setState(() => _composerHeight = height);
  }

  Future<void> _loadAiAuthorization() async {
    try {
      final authorized = await ref
          .read(authRepositoryProvider)
          .fetchAiAuthorization();
      if (mounted) setState(() => _aiAuthorized = authorized);
    } catch (_) {
      if (mounted) setState(() => _aiAuthorized = false);
    }
  }

  void _send() => unawaited(_sendText(_input.text, clearComposer: true));

  Future<void> _sendText(String rawText, {required bool clearComposer}) async {
    final text = rawText.trim();
    if (text.isEmpty || _sendInProgress) return;
    _sendInProgress = true;
    try {
      if (_aiAuthorized == null) {
        await _aiAuthorizationLoad;
        if (!mounted) return;
      }

      if (_aiAuthorized != true) {
        final authorized = await showAiConsentSheet(
          context,
          message: text,
          onAuthorize: () => ref.read(authRepositoryProvider).authorizeAi(),
        );
        if (!mounted) return;
        if (!authorized) return;
        _aiAuthorized = true;
      }

      if (clearComposer) _input.clear();
      HapticFeedback.lightImpact();
      unawaited(
        ref.read(chatControllerProvider(widget.tripId).notifier).send(text),
      );
      // 捲到底(reverse list 底部 = offset 0)。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    } finally {
      _sendInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.tripId));
    final currentUser = switch (ref.watch(authStateProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    // 伺服器沒確認的停止,在這裡推進到終結態 —— row 本身還是 processing。
    final msgs = _locallyStopped.isEmpty
        ? state.messages
        : [
            for (final r in state.requests)
              ...rowToMessages(
                _locallyStopped.contains(r.id) && !r.status.isTerminal
                    ? r.asLocallyStopped()
                    : r,
              ),
          ];
    final hasBanner =
        state.authExpired || (state.error != null && msgs.isNotEmpty);
    final contentTop = hasBanner
        ? TpSpacing.s4
        : TpRootGeometry.initialContentTop(context);

    Widget initiallyBelowHeader(Widget child) => Padding(
      padding: EdgeInsets.only(top: contentTop),
      child: child,
    );

    final controller = ref.read(chatControllerProvider(widget.tripId).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncComposerHeight());
    final messageBottomInset = _composerHeight > 0
        ? _composerHeight + TpSpacing.s2
        : TpRootTabGeometry.clearance(context) + 80;

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              children: [
                if (hasBanner)
                  SizedBox(height: TpRootGeometry.initialContentTop(context)),
                if (state.authExpired) const _Banner(text: '登入已過期,請重新登入後再試。'),
                // 有訊息時錯誤走非阻擋橫幅;空清單(初次載入失敗)走置中錯誤 + 重試。
                if (state.error != null && msgs.isNotEmpty)
                  _Banner(text: state.error!),
                Expanded(
                  child: state.initialLoading
                      ? initiallyBelowHeader(
                          const Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        )
                      : (state.error != null && msgs.isEmpty)
                      ? initiallyBelowHeader(
                          _CenteredHint(
                            title: '載入失敗',
                            body: '無法取得對話,請稍後再試。',
                            onRetry: () => unawaited(controller.reload()),
                          ),
                        )
                      : msgs.isEmpty
                      ? initiallyBelowHeader(
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: messageBottomInset,
                            ),
                            child: _EmptyStatePrompts(
                              sending: state.sending,
                              onSelect: (prompt) => unawaited(
                                _sendText(prompt, clearComposer: false),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: const ValueKey('chat-list'),
                          controller: _scroll,
                          reverse: true,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            TpSpacing.s4,
                            contentTop,
                            TpSpacing.s4,
                            messageBottomInset,
                          ),
                          // reverse list 的最後一項落在視覺頂端 → 載入指示畫在
                          // 更舊訊息即將接上來的那一頭。
                          itemCount: msgs.length + (state.loadingOlder ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= msgs.length) {
                              return const _LoadingOlderIndicator();
                            }
                            final m = msgs[msgs.length - 1 - i];
                            return _MessageBubble(
                              message: m,
                              tripId: widget.tripId,
                              myEmail: currentUser?.email,
                              myDisplayName: currentUser?.displayName,
                              onStopWaiting: _stopWaiting,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        // 捲離最新訊息才出現;疊在訊息之上、輸入區之上方(不遮住輸入區)。
        if (!_atLatest && msgs.isNotEmpty)
          Positioned(
            right: TpSpacing.s4,
            bottom: messageBottomInset + TpSpacing.s2,
            child: _JumpToLatestButton(onPressed: _jumpToLatest),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _syncComposerHeight(),
              );
              return false;
            },
            child: SizeChangedLayoutNotifier(
              key: _composerKey,
              child: _Composer(
                tripId: widget.tripId,
                input: _input,
                sending: state.sending,
                onSend: _send,
                speechAvailable: widget.speechAvailable,
                speechPurposeAccepted: widget.speechPurposeAccepted,
                onSpeechAvailableChanged: widget.onSpeechAvailableChanged,
                onSpeechPurposeAccepted: widget.onSpeechPurposeAccepted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 自動載入更舊時的指示;讀螢幕使用者靠 [Semantics] 得知目前正在載入。
class _LoadingOlderIndicator extends StatelessWidget {
  const _LoadingOlderIndicator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TpSpacing.s3),
    child: Center(
      child: Semantics(
        key: const ValueKey('chat-loading-older'),
        liveRegion: true,
        label: '正在載入更早的訊息',
        child: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      ),
    ),
  );
}

/// 捲離最新訊息時浮出的「回到最新」圓鈕(44pt 可點區域)。
class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TpGlassSurface(
    borderRadius: const BorderRadius.all(Radius.circular(TpSpacing.tapMin / 2)),
    child: SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: IconButton(
        key: const ValueKey('chat-jump-to-latest'),
        tooltip: '回到最新訊息',
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          CupertinoIcons.chevron_down,
          size: 20,
          semanticLabel: '回到最新訊息',
        ),
      ),
    ),
  );
}

String? _emailLocalPart(String? email) {
  final value = email?.trim();
  if (value == null || value.isEmpty) return null;
  final local = value.split('@').first.trim();
  return local.isEmpty ? null : local;
}

/// 三方氣泡:自己(accent,右)/ 協作者(indigo,左+名字)/ AI(neutral,左+名稱)。
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    this.onStopWaiting,
    required this.message,
    required this.tripId,
    required this.myEmail,
    required this.myDisplayName,
  });

  final ChatMessage message;
  final String tripId;
  final String? myEmail;
  final String? myDisplayName;

  /// 停止等待 —— 只在等待中的泡泡上出現。
  final ValueChanged<int>? onStopWaiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isAssistant = message.role == ChatRole.assistant;
    final normalizedMyEmail = myEmail?.trim().toLowerCase();
    final normalizedSenderEmail = message.submittedBy?.trim().toLowerCase();
    // submittedBy 為空(樂觀 temp / 認證未解析)視為自己。
    final isSelf =
        !isAssistant &&
        (normalizedSenderEmail == null ||
            normalizedSenderEmail == normalizedMyEmail);
    final collaboratorAccent = CupertinoColors.systemIndigo.resolveFrom(
      context,
    );

    final Color bg;
    if (message.isFailed) {
      bg = scheme.errorContainer;
    } else if (isAssistant) {
      bg = scheme.surfaceContainerHigh;
    } else if (isSelf) {
      bg = scheme.primaryContainer;
    } else {
      bg = Color.alphaBlend(
        collaboratorAccent.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
        ),
        scheme.surfaceContainerHigh,
      );
    }
    final textColor = message.isFailed
        ? scheme.onErrorContainer
        : scheme.onSurface;

    late final String label;
    late final Color labelColor;
    if (isAssistant) {
      label = 'Tripline AI';
      labelColor = scheme.onSurfaceVariant;
    } else if (isSelf) {
      final displayName = myDisplayName?.trim();
      label = displayName?.isNotEmpty == true
          ? displayName!
          : _emailLocalPart(myEmail) ?? '你';
      labelColor = scheme.onPrimaryContainer;
    } else {
      final senderName = message.senderName?.trim();
      label = senderName?.isNotEmpty == true
          ? senderName!
          : _emailLocalPart(message.submittedBy) ?? '協作者';
      labelColor = collaboratorAccent;
    }

    final Widget content;
    if (message.pendingRequestId case final pendingId?) {
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
          // 次要文字鈕,陪在「思考中…」旁邊 —— 不換掉送出鍵、不進工具列。
          // 送出鍵在等待時變成停止鍵是 Claude／ChatGPT 的慣例,但那個手勢在
          // 那些產品裡是「中止生成」;這裡按下去**不中止 AI**,沿用會騙人。
          // 而且本 app 的輸入框在等待期間本來就沒鎖,換掉送出鍵是倒退。
          if (onStopWaiting != null) ...[
            const SizedBox(width: TpSpacing.s2),
            Semantics(
              button: true,
              label: '停止等待',
              hint: '停止等待這則回覆。AI 若仍在處理，完成後的回報還是會出現，行程也可能已被更動。',
              excludeSemantics: true,
              child: TextButton(
                key: ValueKey('chat-stop-waiting-$pendingId'),
                onPressed: () => onStopWaiting!(pendingId),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, TpSpacing.tapMin),
                  padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('停止等待'),
              ),
            ),
          ],
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
          Padding(
            padding: const EdgeInsets.only(
              left: TpSpacing.s1,
              right: TpSpacing.s1,
              bottom: 2,
            ),
            child: Text(
              label,
              key: ValueKey(
                isAssistant
                    ? 'chat-message-assistant-label'
                    : isSelf
                    ? 'chat-message-self-label'
                    : 'chat-message-collaborator-label',
              ),
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
            child: DecoratedBox(
              key: ValueKey(
                isAssistant
                    ? 'chat-message-assistant'
                    : isSelf
                    ? 'chat-message-self'
                    : 'chat-message-collaborator',
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(TpRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s3,
                  vertical: TpSpacing.s2,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: textColor),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 輸入列:多行 TextField + 語音鈕 + 送出鈕(送出中顯示 spinner)。
/// 語音鈕 lazy:進頁不請求權限;第一次點擊先說明用途，確認後才 init
/// SpeechService(請求麥克風/語音辨識權限)→ 成功則 listen，辨識文字回填
/// 輸入框；init 失敗(權限拒絕/不支援)→ 提供系統設定恢復動線且不 listen。
/// 聆聽中切換 icon/配色，再點則 stop。
enum _ComposerAction { attachment, addEntry }

class _Composer extends ConsumerStatefulWidget {
  const _Composer({
    required this.tripId,
    required this.input,
    required this.sending,
    required this.onSend,
    required this.speechAvailable,
    required this.speechPurposeAccepted,
    required this.onSpeechAvailableChanged,
    required this.onSpeechPurposeAccepted,
  });

  final String tripId;
  final TextEditingController input;
  final bool sending;
  final VoidCallback onSend;
  final bool? speechAvailable;
  final bool speechPurposeAccepted;
  final ValueChanged<bool?> onSpeechAvailableChanged;
  final VoidCallback onSpeechPurposeAccepted;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_inputChanged);
  }

  @override
  void didUpdateWidget(covariant _Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input == widget.input) return;
    oldWidget.input.removeListener(_inputChanged);
    widget.input.addListener(_inputChanged);
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.input.removeListener(_inputChanged);
    super.dispose();
  }

  Future<void> _onAdd() async {
    final action = await showAppActionSheet<_ComposerAction>(
      context,
      title: '加入內容',
      actions: const [
        TpActionItem(
          value: _ComposerAction.attachment,
          label: '加入附件',
          icon: CupertinoIcons.paperclip,
        ),
        TpActionItem(
          value: _ComposerAction.addEntry,
          label: '新增行程項目',
          icon: CupertinoIcons.add_circled,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == _ComposerAction.addEntry) {
      context.push('/trips/${Uri.encodeComponent(widget.tripId)}/entries/new');
      return;
    }
    try {
      final file = await ref.read(chatAttachmentPickerProvider)();
      if (mounted && file != null) {
        showAppNotice(context, '已選擇 ${file.name}');
      }
    } on Exception {
      if (mounted) {
        showAppNotice(context, '無法開啟附件選擇器，請稍後再試。');
      }
    }
  }

  /// lazy init:第一次成功後快取結果,後續沿用不再請求權限。
  Future<bool> _ensureInit() async {
    if (widget.speechAvailable == true) return true;
    final ok = await ref.read(speechServiceProvider).init();
    if (mounted) widget.onSpeechAvailableChanged(ok);
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
    if (widget.speechAvailable == false) {
      await _showSpeechPermissionRecovery();
      return;
    }
    if (!widget.speechPurposeAccepted) {
      final accepted = await showAppConfirm(
        context,
        title: '使用語音輸入？',
        message: 'Tripline 會使用麥克風把你說的話轉成目前行程的文字指令。',
        confirmLabel: '繼續',
      );
      if (!mounted || !accepted) return;
      widget.onSpeechPurposeAccepted();
    }
    final ok = await _ensureInit();
    if (!mounted) return;
    if (!ok) {
      await _showSpeechPermissionRecovery();
      return;
    }
    setState(() => _listening = true);
    await speech.listen((text) {
      if (!mounted) return;
      widget.input.text = text;
      widget.input.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  Future<void> _showSpeechPermissionRecovery() async {
    final openSettings = await showAppConfirm(
      context,
      title: '無法使用語音輸入',
      message: '請到系統設定允許 Tripline 使用麥克風與語音辨識；你的聊天草稿會保留。',
      confirmLabel: '前往系統設定',
      cancelLabel: '稍後再說',
    );
    if (!mounted || !openSettings) return;
    final opened = await ref.read(speechServiceProvider).openSettings();
    if (!mounted) return;
    if (opened) {
      widget.onSpeechAvailableChanged(null);
    } else {
      showAppNotice(context, '無法開啟系統設定，請手動到設定調整權限。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = widget.input.text.trim().isNotEmpty;
    // lazy:預設 enabled,僅送出中 disable;權限在點擊時才檢查。
    final micEnabled = !widget.sending;

    return TextFieldTapRegion(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TpSpacing.s3,
            TpSpacing.s2,
            TpSpacing.s3,
            TpSpacing.s2,
          ),
          child: TpGlassSurface(
            key: const ValueKey('chat-composer-glass'),
            padding: const EdgeInsets.all(TpSpacing.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('chat-add-button'),
                  tooltip: '加入內容',
                  onPressed: widget.sending ? null : () => unawaited(_onAdd()),
                  icon: const Icon(CupertinoIcons.add, semanticLabel: '加入內容'),
                ),
                const SizedBox(width: TpSpacing.s1),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        meta: true,
                      ): widget.onSend,
                    },
                    child: TextField(
                      key: const ValueKey('chat-input'),
                      controller: widget.input,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
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
                ),
                const SizedBox(width: TpSpacing.s2),
                if (hasText)
                  IconButton.filled(
                    key: const ValueKey('chat-send'),
                    tooltip: '送出訊息',
                    onPressed: widget.sending ? null : widget.onSend,
                    icon: widget.sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: Semantics(
                              label: '送出中',
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            semanticLabel: '送出訊息',
                          ),
                  )
                else
                  IconButton(
                    key: const ValueKey('chat-mic-button'),
                    tooltip: _listening ? '停止語音輸入' : '語音輸入',
                    onPressed: micEnabled ? () => unawaited(_onMic()) : null,
                    color: _listening ? scheme.primary : null,
                    icon: Icon(
                      _listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                      semanticLabel: _listening ? '停止語音輸入' : '語音輸入',
                    ),
                  ),
              ],
            ),
          ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TpSpacing.s6),
      child: Center(
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
  const _CenteredHint({
    required this.title,
    required this.body,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            ] else if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: TpSpacing.s4),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
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
