import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedPeerIds = <String>{};
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_isCreating) return;

    setState(() => _isCreating = true);
    try {
      final conversation = await ref
          .read(conversationActionsProvider)
          .createGroupConversation(
            title: _titleController.text,
            invitedPeerIds: _selectedPeerIds.toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final reachableContactsAsync = ref.watch(reachableContactsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('New Group'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'Weekend LAN party',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reachable contacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Only accepted contacts that are reachable right now can be invited.',
            style: TextStyle(color: palette.textMuted),
          ),
          const SizedBox(height: 14),
          reachableContactsAsync.when(
            data: (contacts) {
              if (contacts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: palette.surfaceGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: palette.border.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: palette.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No reachable contacts are available for a group invite right now.',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (final contact in contacts)
                    _SelectableContactCard(
                      peer: contact,
                      selected: _selectedPeerIds.contains(contact.peerId),
                      onChanged: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPeerIds.add(contact.peerId);
                          } else {
                            _selectedPeerIds.remove(contact.peerId);
                          }
                        });
                      },
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                Text('$error', style: TextStyle(color: palette.danger)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isCreating ? null : _createGroup,
            icon: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.group_add_outlined),
            label: Text(
              _selectedPeerIds.isEmpty
                  ? 'Create group'
                  : 'Create group (${_selectedPeerIds.length})',
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableContactCard extends StatelessWidget {
  final PeerRow peer;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _SelectableContactCard({
    required this.peer,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Card(
      color: palette.surface.withValues(alpha: 0.94),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.border.withValues(alpha: 0.18)),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        activeColor: palette.brand,
        secondary: CircleAvatar(
          backgroundColor: palette.positive.withValues(alpha: 0.16),
          child: Icon(Icons.verified_user_outlined, color: palette.positive),
        ),
        title: Text(
          peer.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          peer.deviceLabel ?? peer.fingerprint ?? 'Accepted contact',
          style: TextStyle(color: palette.textMuted),
        ),
      ),
    );
  }
}
