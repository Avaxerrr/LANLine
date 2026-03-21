import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/room_model.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/encryption_manager.dart';
import '../../chat/presentation/chat_screen.dart';
import 'room_setup_screen.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  void _startRoom(BuildContext context, WidgetRef ref, Room room) async {
    // Configure encryption
    if (room.e2eeEnabled && room.password != null && room.password!.isNotEmpty) {
      EncryptionManager().setPassword(room.password!);
    } else {
      EncryptionManager().clearPassword();
    }

    // Start the server with custom port/bind address
    await ref.read(webSocketServerProvider).startServer(
      port: room.port,
      bindAddress: room.bindAddress,
    );

    // Start broadcasting with room metadata
    await ref.read(discoveryServiceProvider).startBroadcasting(
      roomName: room.name,
      e2eeEnabled: room.e2eeEnabled,
      port: room.port,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(room: room, isHost: true)),
      );
    }
  }

  void _deleteRoom(BuildContext context, WidgetRef ref, Room room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Delete Room', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${room.name}"? This cannot be undone.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(roomListProvider.notifier).deleteRoom(room.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Your Rooms', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.meeting_room_outlined, size: 72, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 24),
                  const Text('No rooms yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Create your first chat room to get started.',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Create Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomSetupScreen()),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return _buildRoomCard(context, ref, room);
              },
            ),
      floatingActionButton: rooms.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomSetupScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildRoomCard(BuildContext context, WidgetRef ref, Room room) {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startRoom(context, ref, room),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Room icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Room info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          room.e2eeEnabled ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room.e2eeEnabled ? 'Encrypted' : 'No encryption',
                          style: TextStyle(fontSize: 12, color: room.e2eeEnabled ? Colors.greenAccent : Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                tooltip: 'Edit',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomSetupScreen(existingRoom: room)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                tooltip: 'Delete',
                onPressed: () => _deleteRoom(context, ref, room),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
