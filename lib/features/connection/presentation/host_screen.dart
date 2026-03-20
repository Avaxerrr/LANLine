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
  bool _enablePassword = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    EncryptionManager().clearPassword(); // Always start fresh
    _initHost();
  }

  Future<void> _initHost() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    final ip = await discoveryService.getLocalIpAddress();
    setState(() {
      _localIp = ip;
    });

    if (ip != null) {
      await ref.read(webSocketServerProvider).startServer();
      await discoveryService.startBroadcasting();
    }
  }

  void _enterChatRoom() {
    if (_enablePassword) {
      final pin = _passwordController.text.trim();
      if (pin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a password first!')),
        );
        return;
      }
      EncryptionManager().setPassword(pin);
    } else {
      EncryptionManager().clearPassword();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen(isHost: true)),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    ref.read(discoveryServiceProvider).stop();
    ref.read(webSocketServerProvider).stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host a Room')),
      body: Center(
        child: _localIp == null
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                        size: 220.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Or connect manually to IP: $_localIp',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 24),
                    // E2EE Toggle
                    SwitchListTile(
                      title: const Text('Enable Room Password (E2EE)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_enablePassword
                          ? 'All messages will be AES-256 encrypted'
                          : 'Messages will be sent without encryption'),
                      value: _enablePassword,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _enablePassword = val),
                    ),
                    if (_enablePassword) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          labelText: 'Room Password',
                          hintText: 'Enter any password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.chat_bubble, size: 22),
                        label: const Text('Enter Chat Room',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        onPressed: _enterChatRoom,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
