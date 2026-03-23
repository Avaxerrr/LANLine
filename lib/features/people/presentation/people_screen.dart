import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/v2_data_providers.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final discoveredAsync = ref.watch(discoveredPeersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _SectionHeader(
          title: 'Contacts',
          subtitle: 'Approved peers will appear here.',
        ),
        const SizedBox(height: 12),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? const _SectionPlaceholder(
                  icon: Icons.people_alt_outlined,
                  text: 'No contacts yet',
                )
              : Column(
                  children: [
                    for (final peer in contacts)
                      _PeerCard(
                        title: peer.displayName,
                        subtitle:
                            peer.deviceLabel ??
                            peer.fingerprint ??
                            'Accepted contact',
                        accent: Colors.greenAccent,
                        icon: Icons.verified_user_outlined,
                      ),
                  ],
                ),
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Nearby / Discovered',
          subtitle: 'Phase 3 will populate live discovery and online state.',
        ),
        const SizedBox(height: 12),
        discoveredAsync.when(
          data: (peers) => peers.isEmpty
              ? const _SectionPlaceholder(
                  icon: Icons.radar_outlined,
                  text: 'No discovered peers yet',
                )
              : Column(
                  children: [
                    for (final peer in peers)
                      _PeerCard(
                        title: peer.displayName,
                        subtitle:
                            peer.deviceLabel ??
                            peer.fingerprint ??
                            peer.relationshipState,
                        accent: Colors.orangeAccent,
                        icon: Icons.wifi_tethering_outlined,
                      ),
                  ],
                ),
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _PeerCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.16),
          child: Icon(icon, color: accent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
