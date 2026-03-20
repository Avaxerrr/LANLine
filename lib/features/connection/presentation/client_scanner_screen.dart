import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/models/room_model.dart';
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
  final List<DiscoveredRoom> _discoveredRooms = [];

  @override
  void initState() {
    super.initState();
    EncryptionManager().clearPassword();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    await discoveryService.startListening();
    discoveryService.onRoomDiscovered.listen((room) {
      if (mounted) {
        setState(() {
          // Update or add discovered room
          _discoveredRooms.removeWhere((r) => r.ip == room.ip);
          _discoveredRooms.add(room);
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    ref.read(discoveryServiceProvider).stop();
    super.dispose();
  }

  Future<void> _connectToRoom(DiscoveredRoom discovered) async {
    if (_isConnecting) return;

    if (discovered.e2eeEnabled) {
      // Room has E2EE — ask for password
      final password = await _showPasswordPrompt(discovered.roomName);
      if (password == null) return; // User cancelled
      EncryptionManager().setPassword(password);
    } else {
      // No E2EE — connect directly
      EncryptionManager().clearPassword();
    }

    await _doConnect(discovered);
  }

  Future<void> _connectToIp(String ipAddress) async {
    if (_isConnecting || ipAddress.isEmpty) return;

    // For manual IP entry, we don't know the room details, so ask about E2EE
    final passCtrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Room Password', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('If the room has encryption enabled, enter the password.\nLeave empty if no password was set.',
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

    if (result == null) return;

    if (result.isNotEmpty) {
      EncryptionManager().setPassword(result);
    } else {
      EncryptionManager().clearPassword();
    }

    await _doConnect(DiscoveredRoom(
      ip: ipAddress,
      roomName: 'LANLine Room',
      e2eeEnabled: result.isNotEmpty,
    ));
  }

  Future<String?> _showPasswordPrompt(String roomName) async {
    final passCtrl = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text('Join "$roomName"', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This room is encrypted. Enter the password to join.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Room password',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.key, color: Colors.greenAccent, size: 18),
                filled: true,
                fillColor: const Color(0xFF333333),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final pw = passCtrl.text.trim();
              if (pw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password is required for encrypted rooms')),
                );
                return;
              }
              Navigator.pop(ctx, pw);
            },
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _doConnect(DiscoveredRoom discovered) async {
    setState(() => _isConnecting = true);
    try {
      final client = ref.read(webSocketClientProvider);
      await client.connect(discovered.ip);

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
            _goToChatRoom(discovered);
          } else {
            client.disconnect();
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect password! Try again.')),
            );
          }
        } catch (e) {
          if (mounted) {
            client.disconnect();
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Handshake timed out. Wrong password?')),
            );
          }
        }
      } else {
        _goToChatRoom(discovered);
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

  void _goToChatRoom(DiscoveredRoom discovered) {
    if (mounted) {
      setState(() => _isConnecting = false);

      // Create a transient Room object for the client view
      final room = Room(
        id: 'client_${discovered.ip}',
        name: discovered.roomName,
        e2eeEnabled: discovered.e2eeEnabled,
        createdAt: DateTime.now(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(room: room, isHost: false)),
      );
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isConnecting) return;
    final List barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        try {
          // Try new JSON QR format
          final data = jsonDecode(rawValue);
          final discovered = DiscoveredRoom(
            ip: data['ip'] as String,
            roomName: data['room'] as String? ?? 'LANLine Room',
            e2eeEnabled: data['e2ee'] as bool? ?? false,
          );
          _connectToRoom(discovered);
        } catch (_) {
          // Legacy plain IP QR
          _connectToIp(rawValue);
        }
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
                        'Rooms on your network',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _discoveredRooms.isEmpty
                            ? const Center(child: Text('Scanning for active rooms on your Wi-Fi...', style: TextStyle(fontStyle: FontStyle.italic)))
                            : ListView.builder(
                                itemCount: _discoveredRooms.length,
                                itemBuilder: (context, index) {
                                  final room = _discoveredRooms[index];
                                  return Card(
                                    color: const Color(0xFF1E1E1E),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            room.roomName.isNotEmpty ? room.roomName[0].toUpperCase() : '?',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      title: Text(room.roomName,
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Row(
                                        children: [
                                          Text(room.ip, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(width: 8),
                                          Icon(
                                            room.e2eeEnabled ? Icons.lock : Icons.lock_open,
                                            size: 13,
                                            color: room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            room.e2eeEnabled ? 'Encrypted' : 'Open',
                                            style: TextStyle(fontSize: 11, color: room.e2eeEnabled ? Colors.greenAccent : Colors.grey),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _connectToRoom(room),
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
