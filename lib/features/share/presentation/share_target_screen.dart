import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/conversation_picker_list.dart';
import '../../conversation/presentation/direct_conversation_screen.dart';

/// Screen shown when files are shared into the app from the OS share sheet.
/// Displays a conversation picker so the user can choose who to send to.
class ShareTargetScreen extends ConsumerStatefulWidget {
  final List<String> filePaths;

  const ShareTargetScreen({super.key, required this.filePaths});

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  bool _sending = false;

  /// Copy a shared file from the temporary intent cache to a persistent
  /// location so it survives until the receiver accepts the transfer.
  Future<String> _persistSharedFile(String cachePath) async {
    final cacheFile = File(cachePath);
    final docsDir = await getApplicationDocumentsDirectory();
    final shareDir = Directory(p.join(docsDir.path, 'lanline_shared'));
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }
    final destPath = p.join(shareDir.path, p.basename(cachePath));
    await cacheFile.copy(destPath);
    return destPath;
  }

  Future<void> _sendToConversation(ConversationRow conversation) async {
    if (_sending || conversation.type != 'direct') return;
    setState(() => _sending = true);

    try {
      final peer = await ref.read(
        directConversationPeerProvider(conversation.id).future,
      );
      if (peer == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact is not available.')),
          );
          setState(() => _sending = false);
        }
        return;
      }

      final mediaActions = ref.read(mediaActionsProvider);
      for (final filePath in widget.filePaths) {
        // Copy shared files out of the temporary cache so they remain
        // available when the receiver accepts the transfer later.
        final persistentPath = await _persistSharedFile(filePath);
        await mediaActions.sendFile(
          peerId: peer.peerId,
          conversationId: conversation.id,
          conversationTitle: conversation.title ?? peer.displayName,
          filePath: persistentPath,
        );
      }

      if (mounted) {
        // Replace the share screen with the conversation so the user
        // can see transfer progress, just like the normal attach flow.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DirectConversationScreen(
              conversationId: conversation.id,
              peerId: peer.peerId,
              title: conversation.title ?? peer.displayName,
              conversationType: conversation.type,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final fileNames = widget.filePaths
        .map((path) => p.basename(path))
        .toList();
    final fileLabel = fileNames.length == 1
        ? fileNames.first
        : '${fileNames.length} files';

    return Container(
      decoration: BoxDecoration(color: palette.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: palette.pageGradient),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Share To',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                fileLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _sending
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: palette.brand,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sending...',
                                  style: TextStyle(color: palette.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ConversationPickerList(
                            onSelect: _sendToConversation,
                            directOnly: true,
                            trailingIcon: Icons.send_rounded,
                            emptyMessage:
                                'No conversations yet.\nAdd a contact first to share files.',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
