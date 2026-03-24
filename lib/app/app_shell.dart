import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
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
import 'package:lanline/core/theme/app_theme.dart';

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
      builder: (dialogContext) {
        final palette = dialogContext.appPalette;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.positive.withValues(alpha: 0.15),
                ),
                child: Icon(
                  call.callType == 'video' ? Icons.videocam : Icons.call,
                  size: 36,
                  color: palette.positive,
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
            style: TextStyle(color: palette.textMuted, fontSize: 16),
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
              icon: Icon(Icons.call_end, color: palette.danger),
              label: Text('Decline', style: TextStyle(color: palette.danger)),
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
        );
      },
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
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(color: palette.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: _ShellBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        titles[_selectedIndex],
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Colors.white.withValues(alpha: 0.98),
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
    final palette = context.appPalette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BottomFadeOverlay extends StatelessWidget {
  final double height;

  const _BottomFadeOverlay({required this.height});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.background.withValues(alpha: 0),
            palette.background.withValues(alpha: 0.68),
            palette.background.withValues(alpha: 0.97),
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
    final palette = context.appPalette;
    final enableBlur =
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
    final navigationBar = NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: palette.brand.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(
          Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    );
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: palette.navGlass.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.border.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: enableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: navigationBar,
                )
              : navigationBar,
        ),
      ),
    );
  }
}
