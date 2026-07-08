import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/chat.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pageSize = 5;
  static const _pollInterval = Duration(seconds: 3);

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<TripSummary> _trips = const [];
  List<TripRequest> _requests = const [];
  String? _selectedTripId;
  String? _error;
  bool _loading = true;
  bool _historyLoading = false;
  bool _sending = false;
  bool _pollingNow = false;
  int? _pollingRequestId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrips());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _trips.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadTrips);
    }
    if (_trips.isEmpty) {
      return _EmptyTripsState(onCreateTrip: () => context.go('/trips/new'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('chat-trip-picker'),
            initialValue: _selectedTripId,
            decoration: const InputDecoration(
              labelText: '行程',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final trip in _trips)
                DropdownMenuItem(
                  value: trip.tripId,
                  child: Text(_tripTitle(trip)),
                ),
            ],
            onChanged: _sending
                ? null
                : (tripId) {
                    if (tripId == null || tripId == _selectedTripId) return;
                    setState(() {
                      _selectedTripId = tripId;
                      _requests = const [];
                      _error = null;
                    });
                    _pollTimer?.cancel();
                    _pollingRequestId = null;
                    unawaited(_loadRequests(tripId));
                  },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
            child: _InlineError(message: _error!),
          ),
        Expanded(
          child: _historyLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMessagesList(),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessagesList() {
    final messages = _chatMessages();
    if (messages.isEmpty) {
      return const Center(child: Text('還沒有對話'));
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s2,
        TpSpacing.s4,
        TpSpacing.s4,
      ),
      itemCount: messages.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TpSpacing.s3),
      itemBuilder: (context, index) {
        final message = messages[index];
        return _ChatBubble(message: message);
      },
    );
  }

  Widget _buildComposer() {
    final hasText = _inputController.text.trim().isNotEmpty;
    final canSend =
        _selectedTripId != null &&
        hasText &&
        !_sending &&
        _pollingRequestId == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: _inputController,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '想怎麼調整行程？',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filled(
              key: const ValueKey('chat-send'),
              tooltip: '送出',
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: canSend ? _send : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await ref.read(tripRepositoryProvider).fetchMyTrips();
      if (!mounted) return;
      final selectedTripId = trips.isEmpty ? null : trips.first.tripId;
      setState(() {
        _trips = trips;
        _selectedTripId = selectedTripId;
        _requests = const [];
        _pollingRequestId = null;
        _loading = false;
      });
      if (selectedTripId != null) {
        await _loadRequests(selectedTripId);
      }
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '無法載入聊天資料';
      });
    }
  }

  Future<void> _loadRequests(String tripId) async {
    setState(() {
      _historyLoading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(tripRepositoryProvider)
          .fetchTripRequests(tripId: tripId, limit: _pageSize, sort: 'desc');
      if (!mounted || _selectedTripId != tripId) return;
      final requests = page.items.reversed.toList();
      setState(() {
        _requests = requests;
        _historyLoading = false;
      });
      TripRequest? inflight;
      for (final request in requests) {
        if (request.isInflight) inflight = request;
      }
      if (inflight != null) {
        _startPolling(inflight.id);
      }
      _scrollToBottomSoon();
    } on Exception {
      if (!mounted || _selectedTripId != tripId) return;
      setState(() {
        _historyLoading = false;
        _error = '無法載入對話紀錄';
      });
    }
  }

  Future<void> _send() async {
    final tripId = _selectedTripId;
    final text = _inputController.text.trim();
    if (tripId == null ||
        text.isEmpty ||
        _sending ||
        _pollingRequestId != null) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    _inputController.clear();
    try {
      final request = await ref
          .read(tripRepositoryProvider)
          .createTripRequest(tripId: tripId, message: text);
      if (!mounted || _selectedTripId != tripId) return;
      setState(() {
        _requests = _upsertRequest(_requests, request);
        _sending = false;
      });
      if (request.isInflight) {
        _startPolling(request.id);
      }
      _scrollToBottomSoon();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '送出失敗，請稍後再試';
      });
    }
  }

  void _startPolling(int requestId) {
    _pollTimer?.cancel();
    if (mounted && _pollingRequestId != requestId) {
      setState(() => _pollingRequestId = requestId);
    } else {
      _pollingRequestId = requestId;
    }
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollRequest(requestId));
    });
  }

  Future<void> _pollRequest(int requestId) async {
    if (_pollingNow) return;
    _pollingNow = true;
    try {
      final request = await ref
          .read(tripRepositoryProvider)
          .fetchTripRequest(requestId);
      if (!mounted || _pollingRequestId != requestId) return;
      final completed = !request.isInflight;
      setState(() {
        _requests = _upsertRequest(_requests, request);
        if (completed) {
          _pollingRequestId = null;
        }
      });
      if (completed) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      _scrollToBottomSoon();
    } on Exception {
      if (mounted) {
        setState(() => _error = '暫時無法更新 AI 回覆狀態');
      }
    } finally {
      _pollingNow = false;
    }
  }

  List<TripRequest> _upsertRequest(
    List<TripRequest> current,
    TripRequest request,
  ) {
    final index = current.indexWhere((item) => item.id == request.id);
    if (index == -1) return [...current, request];
    return [...current.take(index), request, ...current.skip(index + 1)];
  }

  List<_ChatMessage> _chatMessages() {
    final messages = <_ChatMessage>[];
    for (final request in _requests) {
      messages.add(
        _ChatMessage(
          key: ValueKey('chat-message-user-${request.id}'),
          role: _ChatRole.user,
          text: request.message,
        ),
      );
      final reply = request.displayReply;
      if (reply != null) {
        messages.add(
          _ChatMessage(
            key: ValueKey('chat-message-assistant-${request.id}'),
            role: _ChatRole.assistant,
            text: reply,
          ),
        );
      } else if (request.isFailed) {
        messages.add(
          _ChatMessage(
            key: ValueKey('chat-message-assistant-${request.id}'),
            role: _ChatRole.assistant,
            text: 'AI 處理失敗，請換個說法或稍後再試。',
            failed: true,
          ),
        );
      } else if (request.isInflight) {
        messages.add(
          _ChatMessage(
            key: ValueKey('chat-message-assistant-${request.id}'),
            role: _ChatRole.assistant,
            text: '思考中...',
            pending: true,
          ),
        );
      }
    }
    return messages;
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  String _tripTitle(TripSummary trip) {
    final title = trip.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return trip.name;
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({
    required this.key,
    required this.role,
    required this.text,
    this.pending = false,
    this.failed = false,
  });

  final Key key;
  final _ChatRole role;
  final String text;
  final bool pending;
  final bool failed;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == _ChatRole.user;
    final colorScheme = theme.colorScheme;
    final background = message.failed
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = message.failed
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pending) ...[
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                ],
                Flexible(
                  child: Text(
                    message.text,
                    key: message.key,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  const _EmptyTripsState({required this.onCreateTrip});

  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('還沒有行程', style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '先建立一趟行程，再用 AI 協助調整安排。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('新增行程'),
              onPressed: onCreateTrip,
            ),
          ],
        ),
      ),
    );
  }
}
