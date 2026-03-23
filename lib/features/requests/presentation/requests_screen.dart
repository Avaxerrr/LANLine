import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/v2_data_providers.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(pendingIncomingRequestsProvider);
    final outgoingAsync = ref.watch(pendingOutgoingRequestsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _RequestHeader(
          title: 'Incoming Requests',
          subtitle: 'Phase 3 will add accept and decline actions here.',
        ),
        const SizedBox(height: 12),
        incomingAsync.when(
          data: (requests) => requests.isEmpty
              ? const _RequestPlaceholder(
                  icon: Icons.mark_email_unread_outlined,
                  text: 'No incoming requests',
                )
              : Column(
                  children: [
                    for (final request in requests)
                      _RequestCard(
                        title: request.peerId,
                        subtitle: request.message ?? 'Incoming request pending',
                        accent: Colors.blueAccent,
                        icon: Icons.call_received,
                      ),
                  ],
                ),
          loading: () => const _RequestLoading(),
          error: (error, stackTrace) =>
              _RequestPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
        const SizedBox(height: 28),
        const _RequestHeader(
          title: 'Outgoing Requests',
          subtitle: 'Pending outbound approvals will appear here.',
        ),
        const SizedBox(height: 12),
        outgoingAsync.when(
          data: (requests) => requests.isEmpty
              ? const _RequestPlaceholder(
                  icon: Icons.outgoing_mail,
                  text: 'No outgoing requests',
                )
              : Column(
                  children: [
                    for (final request in requests)
                      _RequestCard(
                        title: request.peerId,
                        subtitle: request.message ?? 'Outgoing request pending',
                        accent: Colors.orangeAccent,
                        icon: Icons.call_made,
                      ),
                  ],
                ),
          loading: () => const _RequestLoading(),
          error: (error, stackTrace) =>
              _RequestPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
      ],
    );
  }
}

class _RequestHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _RequestHeader({required this.title, required this.subtitle});

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

class _RequestPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RequestPlaceholder({required this.icon, required this.text});

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

class _RequestLoading extends StatelessWidget {
  const _RequestLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _RequestCard({
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
