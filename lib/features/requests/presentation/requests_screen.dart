import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/v2_data_providers.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(pendingIncomingRequestsProvider);
    final outgoingAsync = ref.watch(pendingOutgoingRequestsProvider);
    final requestActions = ref.read(requestActionsProvider);

    Future<void> runRequestAction(
      String successMessage,
      Future<void> Function() action,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _RequestHeader(
          title: 'Incoming Requests',
          subtitle: 'Accept, decline, or block requests from nearby peers.',
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
                        statusLabel: 'Incoming',
                        actions: [
                          _ActionButton(
                            label: 'Accept',
                            icon: Icons.check_circle_outline,
                            foreground: Colors.greenAccent,
                            onPressed: () {
                              unawaited(
                                runRequestAction(
                                  'Accepted request from ${request.peerId}',
                                  () =>
                                      requestActions.acceptRequest(request.id),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            label: 'Decline',
                            icon: Icons.close_outlined,
                            foreground: Colors.orangeAccent,
                            outlined: true,
                            onPressed: () {
                              unawaited(
                                runRequestAction(
                                  'Declined request from ${request.peerId}',
                                  () =>
                                      requestActions.declineRequest(request.id),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            label: 'Block',
                            icon: Icons.block_outlined,
                            foreground: Colors.redAccent,
                            outlined: true,
                            onPressed: () {
                              unawaited(
                                runRequestAction(
                                  'Blocked ${request.peerId}',
                                  () => requestActions.blockPeer(
                                    peerId: request.peerId,
                                    requestId: request.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
          subtitle: 'Track or cancel requests you already sent.',
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
                        statusLabel: 'Sent',
                        actions: [
                          _ActionButton(
                            label: 'Cancel',
                            icon: Icons.remove_circle_outline,
                            foreground: Colors.orangeAccent,
                            onPressed: () {
                              unawaited(
                                runRequestAction(
                                  'Cancelled request to ${request.peerId}',
                                  () =>
                                      requestActions.cancelRequest(request.id),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            label: 'Block',
                            icon: Icons.block_outlined,
                            foreground: Colors.redAccent,
                            outlined: true,
                            onPressed: () {
                              unawaited(
                                runRequestAction(
                                  'Blocked ${request.peerId}',
                                  () => requestActions.blockPeer(
                                    peerId: request.peerId,
                                    requestId: request.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
  final String statusLabel;
  final Color accent;
  final IconData icon;
  final List<Widget> actions;

  const _RequestCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.accent,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: statusLabel, accent: accent),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foreground;
  final VoidCallback onPressed;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: foreground),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: foreground.withValues(alpha: 0.16),
        foregroundColor: foreground,
      ),
      child: child,
    );
  }
}
