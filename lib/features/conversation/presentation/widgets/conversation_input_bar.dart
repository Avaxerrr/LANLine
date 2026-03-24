import 'package:flutter/material.dart';
import 'dart:ui';

class ConversationInputBar extends StatelessWidget {
  final bool supportsDirectMedia;
  final bool isPickingFile;
  final bool isSending;
  final bool isGroup;
  final TextEditingController textController;
  final VoidCallback onPickFile;
  final VoidCallback onSendMessage;
  final String? replyTitle;
  final String? replyPreview;
  final VoidCallback? onClearReply;

  const ConversationInputBar({
    super.key,
    required this.supportsDirectMedia,
    required this.isPickingFile,
    required this.isSending,
    required this.isGroup,
    required this.textController,
    required this.onPickFile,
    required this.onSendMessage,
    this.replyTitle,
    this.replyPreview,
    this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTitle != null &&
                replyPreview != null &&
                onClearReply != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151B26),
                  borderRadius: BorderRadius.circular(18),
                  border: Border(
                    left: BorderSide(
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.reply_outlined,
                        color: Colors.blueAccent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyTitle!,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            replyPreview!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClearReply,
                      icon: const Icon(Icons.close, color: Colors.grey),
                      tooltip: 'Cancel reply',
                    ),
                  ],
                ),
              ),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (supportsDirectMedia) ...[
                        _ComposerCircleButton(
                          onPressed: isPickingFile ? null : onPickFile,
                          child: isPickingFile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: TextField(
                            controller: textController,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSendMessage(),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: isGroup
                                  ? 'Message the group'
                                  : 'Type a message',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.03),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ComposerCircleButton(
                        onPressed: isSending ? null : onSendMessage,
                        filled: true,
                        child: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerCircleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool filled;

  const _ComposerCircleButton({
    required this.onPressed,
    required this.child,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 44,
      height: 44,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: child,
            )
          : IconButton.filledTonal(
              onPressed: onPressed,
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                shape: const CircleBorder(),
              ),
              icon: child,
            ),
    );

    return Center(child: button);
  }
}
