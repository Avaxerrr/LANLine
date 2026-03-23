import 'package:flutter/material.dart';

class ConversationInputBar extends StatelessWidget {
  final bool supportsDirectMedia;
  final bool isPickingFile;
  final bool isSending;
  final bool isGroup;
  final TextEditingController textController;
  final VoidCallback onPickFile;
  final VoidCallback onSendMessage;

  const ConversationInputBar({
    super.key,
    required this.supportsDirectMedia,
    required this.isPickingFile,
    required this.isSending,
    required this.isGroup,
    required this.textController,
    required this.onPickFile,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (supportsDirectMedia) ...[
              IconButton.filledTonal(
                onPressed: isPickingFile ? null : onPickFile,
                icon: isPickingFile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: textController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSendMessage(),
                decoration: InputDecoration(
                  hintText: isGroup ? 'Message the group' : 'Type a message',
                  filled: true,
                  fillColor: const Color(0xFF1B1B1B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: isSending ? null : onSendMessage,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: isSending
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
