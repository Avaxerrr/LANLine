import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/theme/app_theme.dart';

enum MessageMenuAction { reply, copy, forward, pin, delete }

class MessageMenuSlot extends StatelessWidget {
  final bool visible;
  final MessageRow message;
  final bool isPinned;
  final bool showCopy;
  final ValueChanged<MessageRow>? onReply;
  final ValueChanged<MessageRow>? onForward;
  final ValueChanged<MessageRow>? onTogglePin;
  final ValueChanged<MessageRow>? onDelete;

  const MessageMenuSlot({
    super.key,
    required this.visible,
    required this.message,
    required this.isPinned,
    required this.showCopy,
    required this.onReply,
    required this.onForward,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: IgnorePointer(
          ignoring: !visible,
          child: Align(
            child: MessageMenuButton(
              message: message,
              isPinned: isPinned,
              showCopy: showCopy,
              onReply: onReply,
              onForward: onForward,
              onTogglePin: onTogglePin,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}

class MessageMenuButton extends StatelessWidget {
  final MessageRow message;
  final bool isPinned;
  final bool showCopy;
  final ValueChanged<MessageRow>? onReply;
  final ValueChanged<MessageRow>? onForward;
  final ValueChanged<MessageRow>? onTogglePin;
  final ValueChanged<MessageRow>? onDelete;

  const MessageMenuButton({
    super.key,
    required this.message,
    required this.isPinned,
    required this.showCopy,
    required this.onReply,
    required this.onForward,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Tooltip(
      message: 'Message actions',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _showMenu(context, details.globalPosition),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.menuSurface.withValues(alpha: 0.96),
              shape: BoxShape.circle,
              border: Border.all(color: palette.border.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: Icon(Icons.more_horiz, size: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<MessageMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx - 14,
        globalPosition.dy + 14,
        overlay.size.width - globalPosition.dx - 14,
        overlay.size.height - globalPosition.dy - 14,
      ),
      items: [
        PopupMenuItem<MessageMenuAction>(
          value: MessageMenuAction.reply,
          child: _OverflowMenuLabel(
            icon: Icons.reply_outlined,
            label: 'Reply',
            color: context.appPalette.positive,
          ),
        ),
        if (showCopy)
          PopupMenuItem<MessageMenuAction>(
            value: MessageMenuAction.copy,
            child: _OverflowMenuLabel(
              icon: Icons.copy_all_outlined,
              label: 'Copy text',
              color: context.appPalette.brand,
            ),
          ),
        if (showCopy)
          PopupMenuItem<MessageMenuAction>(
            value: MessageMenuAction.forward,
            child: _OverflowMenuLabel(
              icon: Icons.forward_outlined,
              label: 'Forward',
              color: context.appPalette.groupAccent,
            ),
          ),
        PopupMenuItem<MessageMenuAction>(
          value: MessageMenuAction.pin,
          child: _OverflowMenuLabel(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            color: context.appPalette.groupAccent,
          ),
        ),
        PopupMenuItem<MessageMenuAction>(
          value: MessageMenuAction.delete,
          child: _OverflowMenuLabel(
            icon: Icons.delete_outline,
            label: 'Delete from this device',
            color: context.appPalette.danger,
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    await _handleOverflowAction(context, action: action, message: message);
  }

  Future<void> _handleOverflowAction(
    BuildContext context, {
    required MessageMenuAction action,
    required MessageRow message,
  }) async {
    switch (action) {
      case MessageMenuAction.reply:
        onReply?.call(message);
        return;
      case MessageMenuAction.copy:
        final text = message.textBody?.trim() ?? '';
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        return;
      case MessageMenuAction.forward:
        onForward?.call(message);
        return;
      case MessageMenuAction.pin:
        onTogglePin?.call(message);
        return;
      case MessageMenuAction.delete:
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete message'),
            content: const Text(
              'This only removes the message from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPalette.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (shouldDelete == true) {
          onDelete?.call(message);
        }
        return;
    }
  }
}

class _OverflowMenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OverflowMenuLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
