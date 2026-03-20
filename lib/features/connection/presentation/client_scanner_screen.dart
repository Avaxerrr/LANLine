import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/network/encryption_manager.dart';
import '../../chat/presentation/chat_screen.dart';

class ClientScannerScreen extends ConsumerStatefulWidget {
  const ClientScannerScreen({super.key});

  @override
  ConsumerState<ClientScannerScreen> createState() => _ClientScannerScreenState();
}

class _ClientScannerScreenState extends ConsumerState<ClientScannerScreen> {
  bool _isConnecting = false;
  final TextEditingController _ipController = TextEditingController();
  final List<String> _discoveredHosts = [];

  @override
  void initState() {
    super.initState();
    EncryptionManager().clearPassword(); // Always start fresh
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    await discoveryService.startListening();
    discoveryService.onDeviceDiscovered.listen((ip) {
      if (!_discoveredHosts.contains(ip) && mounted) {
        setState(() => _discoveredHosts.add(ip));
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    ref.read(discoveryServiceProvider).stop();
    super.dispose();
  }

  Future<void> _connectToIp(String ipAddress) async {
    if (_isConnecting || ipAddress.isEmpty) return;

    // Ask if the room has a password
    final passCtrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Room Password', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('If the host set a password, enter it below.\nLeave empty if no password was set.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Password (optional)',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, passCtrl.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result == null) return; // User canceled

    // Set or clear encryption based on whether a password was entered
    if (result.isNotEmpty) {
      EncryptionManager().setPassword(result);
    } else {
      EncryptionManager().clearPassword();
    }

    setState(() => _isConnecting = true);
    try {
      final client = ref.read(webSocketClientProvider);
      await client.connect(ipAddress);

      if (!client.isConnected) {
        if (mounted) {
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not connect. Is the host running?')),
          );
        }
        return;
      }

      // If encryption is enabled, do a handshake to verify the password
      if (EncryptionManager().isEnabled) {
        final hsPayload = jsonEncode({'type': 'handshake', 'sender': 'Client'});
        client.sendMessage(hsPayload);

        try {
          final response = await client.onMessageReceived
              .firstWhere((msg) =>
                  msg.contains('"type":"handshake_ack"') ||
                  msg.contains('"type":"error"'))
              .timeout(const Duration(seconds: 5));
          final data = jsonDecode(response);

          if (!mounted) return;

          if (data['type'] == 'handshake_ack') {
            // Password verified!
            _goToChatRoom();
          } else {
            client.disconnect();
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect password! Try again.')),
            );
          }
        } catch (e) {
          // Timeout or parse failure = password mismatch
          if (mounted) {
            client.disconnect();
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Handshake timed out. Wrong password?')),
            );
          }
        }
      } else {
        // No encryption — go straight to chat
        _goToChatRoom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  void _goToChatRoom() {
    if (mounted) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen(isHost: false)),
      );
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isConnecting) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final ipAddress = barcode.rawValue;
      if (ipAddress != null && ipAddress.isNotEmpty) {
        _connectToIp(ipAddress);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Stack(
        children: [
          Column(
            children: [
              if (isMobile)
                Expanded(
                  flex: 2,
                  child: MobileScanner(
                    onDetect: _handleBarcode,
                  ),
                ),
              Expanded(
                flex: isMobile ? 2 : 3,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Discovered Local Hosts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _discoveredHosts.isEmpty
                            ? const Center(child: Text('Scanning for active rooms on your Wi-Fi...', style: TextStyle(fontStyle: FontStyle.italic)))
                            : ListView.builder(
                                itemCount: _discoveredHosts.length,
                                itemBuilder: (context, index) {
                                  final ip = _discoveredHosts[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.wifi, color: Colors.blueAccent),
                                      title: Text('LANLine Server ($ip)'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _connectToIp(ip),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Or connect manually by IP:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 192.168.1.5',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            color: Colors.blueAccent,
                            onPressed: () => _connectToIp(_ipController.text.trim()),
                          ),
                        ),
                        onSubmitted: (value) => _connectToIp(value.trim()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isConnecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
