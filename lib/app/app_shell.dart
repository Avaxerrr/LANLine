import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lanline/core/providers/v2_data_providers.dart';
import 'package:lanline/core/providers/v2_direct_message_protocol_provider.dart';
import 'package:lanline/core/providers/v2_group_protocol_provider.dart';
import 'package:lanline/core/providers/v2_identity_provider.dart';
import 'package:lanline/core/providers/v2_media_protocol_provider.dart';
import 'package:lanline/core/providers/v2_presence_discovery_provider.dart';
import 'package:lanline/core/providers/v2_request_protocol_provider.dart';
import 'package:lanline/features/call/presentation/call_screen.dart';
import 'package:lanline/features/chats/presentation/chats_screen.dart';
import 'package:lanline/features/people/presentation/people_screen.dart';
import 'package:lanline/features/requests/presentation/requests_screen.dart';
import 'package:lanline/features/settings/presentation/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  String? _visibleIncomingCallId;

  void _goToRequests() {
    setState(() => _selectedIndex = 2);
  }

  Future<void> _openCallScreen({
    required String peerId,
    required String title,
    required String conversationId,
    required String callId,
    required String callType,
    required bool isInitiator,
  }) async {
    final localIdentity = await ref.read(identityServiceProvider).bootstrap();
    if (!mounted) return;

    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          myName: localIdentity.displayName,
          remoteDisplayName: title,
          callType: callType,
          isInitiator: isInitiator,
          sendSignal: (payload) {
            unawaited(
              ref
                  .read(mediaActionsProvider)
                  .sendCallSignal(
                    peerId: peerId,
                    conversationId: conversationId,
                    conversationTitle: title,
                    payload: payload,
                  ),
            );
          },
        ),
      ),
    );

    if (result != null && result > 0) {
      await ref
          .read(mediaActionsProvider)
          .addLocalCallSummary(
            conversationId: conversationId,
            callType: callType,
            durationSeconds: result,
          );
    }
  }

  Future<void> _showIncomingCallDialog(V2IncomingCall call) async {
    if (_visibleIncomingCallId == call.callId || !mounted) return;
    _visibleIncomingCallId = call.callId;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.15),
              ),
              child: Icon(
                call.callType == 'video' ? Icons.videocam : Icons.call,
                size: 36,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              call.callType == 'video'
                  ? 'Incoming Video Call'
                  : 'Incoming Call',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          '${call.displayName} is calling...',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(mediaActionsProvider).declineIncomingCall(call);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.call_end, color: Colors.redAccent),
            label: const Text(
              'Decline',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(mediaActionsProvider).clearIncomingCall();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              await _openCallScreen(
                peerId: call.peerId,
                title: call.displayName,
                conversationId: call.conversationId,
                callId: call.callId,
                callType: call.callType,
                isInitiator: false,
              );
            },
            icon: const Icon(Icons.call),
            label: const Text('Accept'),
          ),
        ],
      ),
    );

    _visibleIncomingCallId = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<V2MediaProtocolState>(v2MediaProtocolProvider, (previous, next) {
      final incomingChanged =
          next.incomingCall != null &&
          next.incomingCall?.callId != previous?.incomingCall?.callId;
      if (incomingChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showIncomingCallDialog(next.incomingCall!);
          }
        });
      }

      final noticeChanged =
          next.noticeId != null && next.noticeId != previous?.noticeId;
      if (noticeChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || next.noticeMessage == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.noticeMessage!)));
          await ref.read(mediaActionsProvider).clearNotice();
        });
      }
    });

    ref.watch(v2DirectMessageProtocolControllerProvider);
    ref.watch(v2GroupProtocolControllerProvider);
    ref.watch(v2MediaProtocolProvider);
    ref.watch(v2PresenceDiscoveryControllerProvider);
    ref.watch(v2RequestProtocolControllerProvider);

    final screens = <Widget>[
      ChatsScreen(onGoToRequests: _goToRequests),
      const PeopleScreen(),
      const RequestsScreen(),
      const SettingsScreen(),
    ];

    final titles = ['Chats', 'People', 'Requests', 'Settings'];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151515), Color(0xFF101010)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LANLine',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titles[_selectedIndex],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        body: IndexedStack(index: _selectedIndex, children: screens),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.blueAccent.withValues(alpha: 0.18),
                labelTextStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: 'Chats',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'People',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inbox_outlined),
                    selectedIcon: Icon(Icons.inbox),
                    label: 'Requests',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
