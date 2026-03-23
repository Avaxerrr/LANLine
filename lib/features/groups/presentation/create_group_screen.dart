import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';

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
      final conversation = await ref.read(conversationActionsProvider).createGroupConversation(
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
    final reachableContactsAsync = ref.watch(reachableContactsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
            decoration: InputDecoration(
              labelText: 'Group name',
              hintText: 'Weekend LAN party',
              filled: true,
              fillColor: const Color(0xFF1B1B1B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reachable contacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Only accepted contacts that are reachable right now can be invited.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 14),
          reachableContactsAsync.when(
            data: (contacts) {
              if (contacts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: Colors.grey),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No reachable contacts are available for a group invite right now.',
                          style: TextStyle(color: Colors.grey),
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
            error: (error, stackTrace) => Text(
              '$error',
              style: const TextStyle(color: Colors.redAccent),
            ),
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
    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        activeColor: Colors.blueAccent,
        secondary: CircleAvatar(
          backgroundColor: Colors.greenAccent.withValues(alpha: 0.16),
          child: const Icon(Icons.verified_user_outlined, color: Colors.greenAccent),
        ),
        title: Text(
          peer.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          peer.deviceLabel ?? peer.fingerprint ?? 'Accepted contact',
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
