import 'dart:async';
import 'dart:ui';

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
  static const _navOverlayHeight = 96.0;
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
      final incomingCall = next.incomingCall;
      final incomingChanged =
          incomingCall != null &&
          incomingCall.callId != previous?.incomingCall?.callId;
      if (incomingChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showIncomingCallDialog(incomingCall);
          }
        });
      }

      final noticeMessage = next.noticeMessage;
      final noticeChanged =
          next.noticeId != null && next.noticeId != previous?.noticeId;
      if (noticeChanged && noticeMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(noticeMessage)));
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
      decoration: const BoxDecoration(color: Color(0xFF091018)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: _ShellBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        titles[_selectedIndex],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _BottomFadeOverlay(height: _navOverlayHeight + 44),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _FloatingShellNav(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1826), Color(0xFF091018)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.09),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.04),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomFadeOverlay extends StatelessWidget {
  final double height;

  const _BottomFadeOverlay({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF091018).withValues(alpha: 0),
            const Color(0xFF091018).withValues(alpha: 0.66),
            const Color(0xFF091018).withValues(alpha: 0.96),
          ],
        ),
      ),
    );
  }
}

class _FloatingShellNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _FloatingShellNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
                selectedIndex: selectedIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                onDestinationSelected: onDestinationSelected,
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
