import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/conversation_picker_list.dart';

class ForwardMessageSheet extends StatelessWidget {
  final String currentConversationId;
  final ValueChanged<ConversationRow> onSelectConversation;

  const ForwardMessageSheet({
    super.key,
    required this.currentConversationId,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Forward To',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ConversationPickerList(
                onSelect: onSelectConversation,
                excludeConversationId: currentConversationId,
                emptyMessage:
                    'No other chats available to forward into yet.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
