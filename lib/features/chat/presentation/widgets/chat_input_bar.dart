import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The message input bar at the bottom of the chat screen.
///
/// Contains: attachment menu button, clipboard button, text field, send button.
/// All actions are delegated to the parent via callbacks.
class ChatInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final bool hasParticipants;
  final bool isRecording;

  final VoidCallback onSendMessage;
  final VoidCallback onSendTypingStatus;
  final VoidCallback onSyncClipboard;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onShowNoParticipantsWarning;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.textFocusNode,
    required this.hasParticipants,
    required this.isRecording,
    required this.onSendMessage,
    required this.onSendTypingStatus,
    required this.onSyncClipboard,
    required this.onShowAttachmentMenu,
    required this.onShowNoParticipantsWarning,
  });

  @override
  Widget build(BuildContext context) {
    final disabledColor = Colors.grey.shade700;
    final bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // "+" menu button
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(Icons.add_circle_outline, color: hasParticipants ? Colors.blueAccent : disabledColor, size: 28),
                tooltip: 'Attach',
                onPressed: () {
                  if (!hasParticipants) {
                    onShowNoParticipantsWarning();
                    return;
                  }
                  onShowAttachmentMenu();
                },
              ),
            ),
            // Clipboard button (quick access)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(Icons.content_paste, color: hasParticipants ? Colors.greenAccent : disabledColor, size: 24),
                tooltip: 'Sync Clipboard',
                onPressed: onSyncClipboard,
              ),
            ),
            const SizedBox(width: 4),
            // Expandable text field
            Expanded(
              child: KeyboardListener(
                focusNode: textFocusNode,
                onKeyEvent: isDesktop ? (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    onSendMessage();
                  }
                } : null,
                child: TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: isDesktop ? TextInputAction.none : TextInputAction.send,
                  onChanged: (_) => onSendTypingStatus(),
                  decoration: InputDecoration(
                    hintText: hasParticipants ? 'Type a message...' : 'Waiting for someone to join...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF333333),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: isDesktop ? null : (_) => onSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: CircleAvatar(
                backgroundColor: hasParticipants ? Colors.blueAccent : disabledColor,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: onSendMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The attachment menu shown as a bottom sheet.
///
/// Contains grid of attachment options: File, Gallery, Camera, Clipboard, Voice Memo.
class AttachmentMenu extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPickFile;
  final VoidCallback onPickFromGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onSyncClipboard;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const AttachmentMenu({
    super.key,
    required this.isRecording,
    required this.onPickFile,
    required this.onPickFromGallery,
    required this.onTakePhoto,
    required this.onSyncClipboard,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _attachmentGridItem(
                  icon: Icons.attach_file,
                  label: 'File',
                  color: Colors.blueAccent,
                  onTap: () { Navigator.pop(context); onPickFile(); },
                ),
                _attachmentGridItem(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purpleAccent,
                  onTap: () { Navigator.pop(context); onPickFromGallery(); },
                ),
                if (isMobile)
                  _attachmentGridItem(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.orangeAccent,
                    onTap: () { Navigator.pop(context); onTakePhoto(); },
                  ),
                _attachmentGridItem(
                  icon: Icons.content_paste,
                  label: 'Clipboard',
                  color: Colors.greenAccent,
                  onTap: () { Navigator.pop(context); onSyncClipboard(); },
                ),
                _attachmentGridItem(
                  icon: isRecording ? Icons.stop : Icons.mic,
                  label: isRecording ? 'Stop' : 'Voice Memo',
                  color: isRecording ? Colors.red : Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    if (isRecording) {
                      onStopRecording();
                    } else {
                      onStartRecording();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _attachmentGridItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
