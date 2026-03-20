import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/encryption_manager.dart';
import '../../chat/presentation/chat_screen.dart';

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
  String? _localIp;
  String? _roomPassword;

  @override
  void initState() {
    super.initState();
    _roomPassword = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
    EncryptionManager().setPassword(_roomPassword!);
    _initHost();
  }

  Future<void> _initHost() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    final ip = await discoveryService.getLocalIpAddress();
    setState(() {
      _localIp = ip;
    });

    if (ip != null) {
      // Start the server to accept connections
      await ref.read(webSocketServerProvider).startServer();
      // Start broadcasting mDNS/UDP presence
      await discoveryService.startBroadcasting();
    }
  }

  @override
  void dispose() {
    ref.read(discoveryServiceProvider).stop();
    ref.read(webSocketServerProvider).stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host a Connection')),
      body: Center(
        child: _localIp == null
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Scan this QR code from the mobile app:', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(
                    'Listening on port 55556\nWaiting for participants...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Room Password: $_roomPassword',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: _localIp!,
                      version: QrVersions.auto,
                      size: 250.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Or connect manually to IP: $_localIp', 
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen(isHost: true)));
                    },
                    child: const Text('Enter Chat Room'),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
