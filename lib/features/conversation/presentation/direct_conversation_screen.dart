import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../../core/providers/v2_identity_provider.dart';
import '../../../core/providers/v2_media_protocol_provider.dart';
import '../../call/presentation/call_screen.dart';
import 'widgets/conversation_chrome.dart';
import 'widgets/conversation_input_bar.dart';
import 'widgets/conversation_message_bubble.dart';

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
    extends ConsumerState<DirectConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isPickingFile = false;
  MessageRow? _replyingToMessage;

  bool get _isGroup => widget.conversationType == 'group';
  bool get _supportsDirectMedia => !_isGroup && widget.peerId != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(conversationActionsProvider)
          .setActiveConversation(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    ref.read(conversationActionsProvider).setActiveConversation(null);
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(conversationActionsProvider)
          .sendTextMessage(
            peerId: widget.peerId,
            text: text,
            conversationId: widget.conversationId,
            conversationTitle: widget.title,
            replyToMessageId: _replyingToMessage?.id,
          );
      _textController.clear();
      _clearReply();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
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
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setReply(MessageRow message) {
    setState(() => _replyingToMessage = message);
  }

  void _clearReply() {
    if (_replyingToMessage == null) return;
    setState(() => _replyingToMessage = null);
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
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final localIdentityAsync = ref.watch(localIdentityProvider);
    final mediaState = ref.watch(v2MediaProtocolProvider);
    final membersAsync = ref.watch(
      conversationMemberPeersProvider(widget.conversationId),
    );
    final memberRowsAsync = ref.watch(
      conversationMembersProvider(widget.conversationId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: ConversationTitle(
          title: widget.title,
          conversationType: widget.conversationType,
          membersAsync: memberRowsAsync,
        ),
        backgroundColor: Colors.transparent,
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
      body: Column(
        children: [
          if (_isGroup) const GroupConversationNotice(),
          Expanded(
            child: localIdentityAsync.when(
              data: (localIdentity) => messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return ConversationEmptyState(isGroup: _isGroup);
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients &&
                        _scrollController.position.maxScrollExtent > 0) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });

                  return membersAsync.when(
                    data: (members) {
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

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe =
                              message.senderPeerId == localIdentity?.peerId;
                          return ConversationMessageBubble(
                            message: message,
                            isMe: isMe,
                            peerId: widget.peerId,
                            isGroup: _isGroup,
                            senderLabel:
                                memberNameByPeerId[message.senderPeerId] ??
                                message.senderPeerId,
                            downloadProgress: mediaState.downloadProgress,
                            showStatus: isMe && message.id == latestMessageId,
                            repliedMessage: message.replyToMessageId == null
                                ? null
                                : messageById[message.replyToMessageId!],
                            onReply: _setReply,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        ConversationError(message: '$error'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    ConversationError(message: '$error'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  ConversationError(message: '$error'),
            ),
          ),
          ConversationInputBar(
            supportsDirectMedia: _supportsDirectMedia,
            isPickingFile: _isPickingFile,
            isSending: _isSending,
            isGroup: _isGroup,
            textController: _textController,
            onPickFile: _pickAndSendFile,
            onSendMessage: _sendMessage,
            replyTitle: _replyingToMessage == null ? null : 'Replying',
            replyPreview: _replyingToMessage == null
                ? null
                : _replyPreviewText(_replyingToMessage!),
            onClearReply: _replyingToMessage == null ? null : _clearReply,
          ),
        ],
      ),
    );
  }
}
