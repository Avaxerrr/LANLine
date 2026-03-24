import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../../core/providers/v2_identity_provider.dart';
import '../../../core/providers/v2_media_protocol_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../call/presentation/call_screen.dart';
import 'widgets/conversation_chrome.dart';
import 'widgets/conversation_input_bar.dart';
import 'widgets/conversation_message_bubble.dart';
import 'widgets/forward_message_sheet.dart';

class DirectConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? peerId;
  final String title;
  final String conversationType;

  const DirectConversationScreen({
    super.key,
    required this.conversationId,
    required this.peerId,
    required this.title,
    required this.conversationType,
  });

  @override
  ConsumerState<DirectConversationScreen> createState() =>
      _DirectConversationScreenState();
}

class _DirectConversationScreenState
    extends ConsumerState<DirectConversationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isPickingFile = false;
  MessageRow? _replyingToMessage;
  String? _activeMessageActionsId;
  bool _didInitialAutoScroll = false;
  int _lastObservedMessageCount = 0;
  bool _isLoadingOlder = false;
  double _lastKeyboardInset = 0;

  bool get _isGroup => widget.conversationType == 'group';
  bool get _supportsDirectMedia => !_isGroup && widget.peerId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerFocusNode.addListener(_handleComposerFocusChange);
    Future.microtask(() async {
      ref
              .read(
                conversationMessagePageSizeProvider(
                  widget.conversationId,
                ).notifier,
              )
              .state =
          50;
      await ref
          .read(conversationActionsProvider)
          .setActiveConversation(widget.conversationId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composerFocusNode
      ..removeListener(_handleComposerFocusChange)
      ..dispose();
    _textController.dispose();
    _scrollController.dispose();
    ref
            .read(
              conversationMessagePageSizeProvider(
                widget.conversationId,
              ).notifier,
            )
            .state =
        50;
    ref.read(conversationActionsProvider).setActiveConversation(null);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_composerFocusNode.hasFocus) return;
    _scheduleKeepLatestVisible();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    final previousReply = _replyingToMessage;

    setState(() {
      _isSending = true;
      _textController.clear();
      _replyingToMessage = null;
    });
    try {
      await ref
          .read(conversationActionsProvider)
          .sendTextMessage(
            peerId: widget.peerId,
            text: text,
            conversationId: widget.conversationId,
            conversationTitle: widget.title,
            replyToMessageId: previousReply?.id,
          );
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_textController.text.isEmpty) {
          _textController.text = text;
        }
        _replyingToMessage = previousReply;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_isPickingFile || !_supportsDirectMedia) return;
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path == null) return;

      await ref
          .read(mediaActionsProvider)
          .sendFile(
            peerId: widget.peerId!,
            conversationId: widget.conversationId,
            conversationTitle: widget.title,
            filePath: path,
          );
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send file: $error')));
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  Future<void> _startCall(String callType) async {
    if (!_supportsDirectMedia) return;

    try {
      await ref
          .read(mediaActionsProvider)
          .prepareOutgoingCall(
            peerId: widget.peerId!,
            conversationId: widget.conversationId,
            conversationTitle: widget.title,
            callType: callType,
          );

      final localIdentity = await ref.read(identityServiceProvider).bootstrap();
      if (!mounted) return;

      final result = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
            myName: localIdentity.displayName,
            remoteDisplayName: widget.title,
            callType: callType,
            isInitiator: true,
            sendSignal: (payload) {
              unawaited(
                ref
                    .read(mediaActionsProvider)
                    .sendCallSignal(
                      peerId: widget.peerId!,
                      conversationId: widget.conversationId,
                      conversationTitle: widget.title,
                      payload: payload,
                    ),
              );
            },
          ),
        ),
      );

      if (result != null && result > 0) {
        await ref
            .read(mediaActionsProvider)
            .addLocalCallSummary(
              conversationId: widget.conversationId,
              callType: callType,
              durationSeconds: result,
            );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start call: $error')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _scheduleKeepLatestVisible() {
    _scrollToBottom();
    Future<void>.delayed(const Duration(milliseconds: 80), _scrollToBottom);
    Future<void>.delayed(const Duration(milliseconds: 180), _scrollToBottom);
    Future<void>.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _handleComposerFocus() {
    _scheduleKeepLatestVisible();
  }

  void _handleComposerFocusChange() {
    if (_composerFocusNode.hasFocus) {
      _scheduleKeepLatestVisible();
    }
  }

  void _setReply(MessageRow message) {
    setState(() {
      _replyingToMessage = message;
      _activeMessageActionsId = null;
    });
  }

  void _clearReply() {
    if (_replyingToMessage == null) return;
    setState(() => _replyingToMessage = null);
  }

  void _toggleMessageActions(String messageId) {
    setState(() {
      _activeMessageActionsId = _activeMessageActionsId == messageId
          ? null
          : messageId;
    });
  }

  void _maybeLoadOlderMessages({
    required int loadedMessageCount,
    required int currentPageSize,
  }) {
    if (_isLoadingOlder || loadedMessageCount < currentPageSize) {
      return;
    }
    _isLoadingOlder = true;
    final notifier = ref.read(
      conversationMessagePageSizeProvider(widget.conversationId).notifier,
    );
    notifier.state = notifier.state + 50;
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      _isLoadingOlder = false;
    });
  }

  Future<void> _deleteMessage(MessageRow message) async {
    try {
      await ref.read(conversationActionsProvider).deleteMessage(message.id);
      if (_replyingToMessage?.id == message.id) {
        _clearReply();
      }
      if (_activeMessageActionsId == message.id && mounted) {
        setState(() => _activeMessageActionsId = null);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $error')),
      );
    }
  }

  Future<void> _forwardMessage(MessageRow message) async {
    final text = message.textBody?.trim();
    if (text == null || text.isEmpty) return;
    if (!mounted) return;

    setState(() => _activeMessageActionsId = null);

    final targetConversation = await showModalBottomSheet<ConversationRow>(
      context: context,
      backgroundColor: context.appPalette.menuSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: ForwardMessageSheet(
          currentConversationId: widget.conversationId,
          onSelectConversation: (conversation) {
            Navigator.pop(sheetContext, conversation);
          },
        ),
      ),
    );

    if (targetConversation == null) return;

    try {
      String? targetPeerId;
      if (targetConversation.type == 'direct') {
        final peer = await ref.read(
          directConversationPeerProvider(targetConversation.id).future,
        );
        targetPeerId = peer?.peerId;
        if (targetPeerId == null) {
          throw StateError('Could not resolve the target contact.');
        }
      }

      await ref
          .read(conversationActionsProvider)
          .sendTextMessage(
            peerId: targetPeerId,
            text: text,
            conversationId: targetConversation.id,
            conversationTitle: targetConversation.title,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Forwarded to ${targetConversation.title ?? 'conversation'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to forward message: $error')),
      );
    }
  }

  Future<void> _togglePin(MessageRow message) async {
    try {
      setState(() => _activeMessageActionsId = null);
      final conversation = await ref.read(
        conversationStreamProvider(widget.conversationId).future,
      );
      if (conversation == null) {
        throw StateError('Conversation was not found.');
      }

      if (conversation.pinnedMessageId == message.id) {
        await ref
            .read(conversationActionsProvider)
            .clearPinnedMessage(widget.conversationId);
      } else {
        await ref
            .read(conversationActionsProvider)
            .pinMessage(
              conversationId: widget.conversationId,
              messageId: message.id,
            );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update pin: $error')));
    }
  }

  void _maybeAutoScroll(List<MessageRow> messages, String? localPeerId) {
    final shouldInitialScroll = !_didInitialAutoScroll && messages.isNotEmpty;
    final hasNewMessage = messages.length > _lastObservedMessageCount;

    bool nearBottom = true;
    if (_scrollController.hasClients) {
      nearBottom = _scrollController.offset <= 120;
    }

    final latestIsMine =
        messages.isNotEmpty && messages.last.senderPeerId == localPeerId;

    _lastObservedMessageCount = messages.length;

    if (!(shouldInitialScroll ||
        (hasNewMessage && (nearBottom || latestIsMine)))) {
      return;
    }

    _didInitialAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (shouldInitialScroll) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _messagePreviewText(MessageRow message) {
    final text = message.textBody?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    switch (message.type) {
      case 'file':
        return 'Attachment';
      case 'call_summary':
        return 'Call summary';
      case 'system':
        return 'System message';
      default:
        return message.type;
    }
  }

  String _replyPreviewText(MessageRow message) {
    final text = message.textBody?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    switch (message.type) {
      case 'file':
        return 'Attachment';
      case 'call_summary':
        return 'Call summary';
      case 'system':
        return 'System message';
      default:
        return message.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    if (keyboardInset != _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
    }
    final composerHeight = _replyingToMessage == null ? 116.0 : 196.0;
    final composerBottomInset =
        mediaQuery.padding.bottom + composerHeight + keyboardInset + 6;
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final currentPageSize = ref.watch(
      conversationMessagePageSizeProvider(widget.conversationId),
    );
    final conversationAsync = ref.watch(
      conversationStreamProvider(widget.conversationId),
    );
    final localIdentityAsync = ref.watch(localIdentityProvider);
    final mediaState = ref.watch(v2MediaProtocolProvider);
    final membersAsync = ref.watch(
      conversationMemberPeersProvider(widget.conversationId),
    );
    final memberRowsAsync = ref.watch(
      conversationMembersProvider(widget.conversationId),
    );
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: ConversationTitle(
          title: widget.title,
          conversationType: widget.conversationType,
          membersAsync: memberRowsAsync,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 74,
        titleSpacing: 16,
        elevation: 0,
        actions: _supportsDirectMedia
            ? [
                IconButton(
                  onPressed: () => _startCall('audio'),
                  icon: const Icon(Icons.call),
                  tooltip: 'Audio call',
                ),
                IconButton(
                  onPressed: () => _startCall('video'),
                  icon: const Icon(Icons.videocam),
                  tooltip: 'Video call',
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _ConversationBackdrop()),
          Column(
            children: [
              if (_isGroup) const GroupConversationNotice(),
              conversationAsync.when(
                data: (conversation) {
                  final pinnedMessageId = conversation?.pinnedMessageId;
                  if (pinnedMessageId == null) {
                    return const SizedBox.shrink();
                  }
                  return messagesAsync.maybeWhen(
                    data: (messages) {
                      MessageRow? pinned;
                      for (final message in messages) {
                        if (message.id == pinnedMessageId) {
                          pinned = message;
                          break;
                        }
                      }
                      if (pinned == null) {
                        return const SizedBox.shrink();
                      }
                      return PinnedMessageBanner(
                        preview: _messagePreviewText(pinned),
                        onUnpin: () => ref
                            .read(conversationActionsProvider)
                            .clearPinnedMessage(widget.conversationId),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
              Expanded(
                child: localIdentityAsync.when(
                  data: (localIdentity) => messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return ConversationEmptyState(isGroup: _isGroup);
                      }
                      _maybeAutoScroll(messages, localIdentity?.peerId);
                      if (!_didInitialAutoScroll && messages.isNotEmpty) {
                        _jumpToBottom();
                      }

                      return membersAsync.when(
                        data: (members) {
                          final reversedMessages = messages.reversed.toList(
                            growable: false,
                          );
                          final memberNameByPeerId = {
                            for (final member in members)
                              member.peerId: member.displayName,
                          };
                          final messageById = {
                            for (final message in messages) message.id: message,
                          };
                          final latestMessageId = latestOutgoingMessageId(
                            messages,
                            localIdentity?.peerId,
                          );

                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.pixels >=
                                      notification.metrics.maxScrollExtent -
                                          80 &&
                                  notification.metrics.axis == Axis.vertical) {
                                _maybeLoadOlderMessages(
                                  loadedMessageCount: messages.length,
                                  currentPageSize: currentPageSize,
                                );
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                composerBottomInset,
                                16,
                                16,
                              ),
                              itemCount: reversedMessages.length,
                              itemBuilder: (context, index) {
                                final message = reversedMessages[index];
                                final isMe =
                                    message.senderPeerId ==
                                    localIdentity?.peerId;
                                final replyMessageId = message.replyToMessageId;
                                return ConversationMessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  peerId: widget.peerId,
                                  isGroup: _isGroup,
                                  senderLabel:
                                      memberNameByPeerId[message
                                          .senderPeerId] ??
                                      message.senderPeerId,
                                  downloadProgress: mediaState.downloadProgress,
                                  showStatus:
                                      isMe && message.id == latestMessageId,
                                  repliedMessage: replyMessageId == null
                                      ? null
                                      : messageById[replyMessageId],
                                  onReply: _setReply,
                                  onDelete: _deleteMessage,
                                  onForward: _forwardMessage,
                                  onTogglePin: _togglePin,
                                  showInlineActions:
                                      _activeMessageActionsId == message.id,
                                  onToggleActions: () =>
                                      _toggleMessageActions(message.id),
                                  isPinned: conversationAsync.maybeWhen(
                                    data: (conversation) =>
                                        conversation?.pinnedMessageId ==
                                        message.id,
                                    orElse: () => false,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) =>
                            ConversationError(message: '$error'),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        ConversationError(message: '$error'),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      ConversationError(message: '$error'),
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            height: composerBottomInset + 28,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.background.withValues(alpha: 0),
                      palette.background.withValues(alpha: 0.14),
                      palette.background.withValues(alpha: 0.42),
                      palette.background.withValues(alpha: 0.78),
                    ],
                    stops: const [0, 0.38, 0.72, 1],
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: ConversationInputBar(
              supportsDirectMedia: _supportsDirectMedia,
              isPickingFile: _isPickingFile,
              isSending: _isSending,
              isGroup: _isGroup,
              textController: _textController,
              focusNode: _composerFocusNode,
              onPickFile: _pickAndSendFile,
              onSendMessage: _sendMessage,
              onFocusComposer: _handleComposerFocus,
              replyTitle: _replyingToMessage == null ? null : 'Replying',
              replyPreview: _replyingToMessage == null
                  ? null
                  : _replyPreviewText(_replyingToMessage!),
              onClearReply: _replyingToMessage == null ? null : _clearReply,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationBackdrop extends StatelessWidget {
  const _ConversationBackdrop();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.85, -1.1),
            radius: 1.15,
            colors: [
              palette.backgroundAlt.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
