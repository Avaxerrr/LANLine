import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:lanline/core/providers/data_providers.dart';
import 'package:lanline/core/providers/direct_message_protocol_provider.dart';
import 'package:lanline/core/providers/group_protocol_provider.dart';
import 'package:lanline/core/providers/identity_provider.dart';
import 'package:lanline/core/providers/call_signaling_provider.dart';
import 'package:lanline/core/providers/file_transfer_protocol_provider.dart';
import 'package:lanline/core/providers/presence_discovery_provider.dart';
import 'package:lanline/core/providers/request_protocol_provider.dart';
import 'package:lanline/features/call/presentation/call_screen.dart';
import 'package:lanline/features/chats/presentation/chats_screen.dart';
import 'package:lanline/features/people/presentation/people_screen.dart';
import 'package:lanline/features/requests/presentation/requests_screen.dart';
import 'package:lanline/features/settings/presentation/settings_screen.dart';
import 'package:lanline/features/share/presentation/share_target_screen.dart';
import 'package:lanline/core/theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _navOverlayHeight = 104.0;
  int _selectedIndex = 0;
  String? _visibleIncomingCallId;
  StreamSubscription<List<SharedMediaFile>>? _shareIntentSub;
  bool _shareScreenOpen = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Handle files shared while app is already running
      _shareIntentSub = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_handleSharedFiles, onError: (_) {});

      // Handle files shared when app was closed (cold start)
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((files) {
        if (files.isNotEmpty) _handleSharedFiles(files);
      });
    }
  }

  @override
  void dispose() {
    _shareIntentSub?.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty || !mounted || _shareScreenOpen) return;
    final paths = files
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;

    _shareScreenOpen = true;
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ShareTargetScreen(filePaths: paths),
          ),
        )
        .then((sent) {
      _shareScreenOpen = false;
      ReceiveSharingIntent.instance.reset();
    });
  }

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
                  .read(callSignalingActionsProvider)
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
          .read(callSignalingActionsProvider)
          .addLocalCallSummary(
            conversationId: conversationId,
            callType: callType,
            durationSeconds: result,
            senderPeerId: isInitiator ? null : peerId,
          );
    }
  }

  Future<void> _showIncomingCallDialog(IncomingCall call) async {
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
                await ref.read(callSignalingActionsProvider).declineIncomingCall(call);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              icon: Icon(Icons.call_end, color: palette.danger),
              label: Text('Decline', style: TextStyle(color: palette.danger)),
            ),
            FilledButton.icon(
              onPressed: () async {
                await ref.read(callSignalingActionsProvider).clearIncomingCall();
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
    ref.listen<CallSignalingState>(callSignalingProvider, (previous, next) {
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
          await ref.read(callSignalingActionsProvider).clearNotice();
        });
      }
    });

    ref.watch(directMessageProtocolControllerProvider);
    ref.watch(groupProtocolControllerProvider);
    ref.watch(fileTransferProtocolProvider);
    ref.watch(callSignalingProvider);
    ref.watch(presenceDiscoveryControllerProvider);
    ref.watch(requestProtocolControllerProvider);

    final screens = <Widget>[
      ChatsScreen(onGoToRequests: _goToRequests),
      const PeopleScreen(),
      const RequestsScreen(),
      const SettingsScreen(),
    ];

    final titles = ['Chats', 'People', 'Requests', 'Settings'];
    final palette = context.appPalette;
    final mediaQuery = MediaQuery.of(context);
    final navBottomInset = mediaQuery.padding.bottom > 0
        ? mediaQuery.padding.bottom + 8
        : 14.0;
    return Container(
      decoration: BoxDecoration(color: palette.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _BottomFadeOverlay(
                  height: _navOverlayHeight + navBottomInset + 24,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _FloatingShellNav(
                selectedIndex: _selectedIndex,
                bottomInset: navBottomInset,
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
  final double bottomInset;
  final ValueChanged<int> onDestinationSelected;

  const _FloatingShellNav({
    required this.selectedIndex,
    required this.bottomInset,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final enableBlur = !isMobile;
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
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
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
        child: isMobile
            ? _CompactMobileNavBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
              )
            : enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: navigationBar,
              )
            : navigationBar,
      ),
    );
  }
}

class _CompactMobileNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _CompactMobileNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, IconData selectedIcon, String label})>[
      (
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: 'Chats',
      ),
      (icon: Icons.people_outline, selectedIcon: Icons.people, label: 'People'),
      (
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        label: 'Requests',
      ),
      (
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ];

    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _CompactMobileNavItem(
                label: items[i].label,
                icon: i == selectedIndex
                    ? items[i].selectedIcon
                    : items[i].icon,
                selected: i == selectedIndex,
                onTap: () => onDestinationSelected(i),
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactMobileNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppThemePalette palette;

  const _CompactMobileNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? palette.brand.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : palette.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
