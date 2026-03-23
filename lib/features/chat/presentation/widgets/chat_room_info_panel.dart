import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/models/room_model.dart';

/// Shows room info as a draggable bottom sheet: room name, connection info,
/// encryption status, participant list, and QR code for sharing.
void showRoomInfoPanel({
  required BuildContext context,
  required Room room,
  required bool isHost,
  required String myName,
  required String? localIp,
  required int participantCount,
  required List<String> participantNames,
  required bool hasParticipants,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(room.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _infoTile(Icons.wifi, 'Connection',
                isHost ? 'Host • ${localIp ?? "Loading..."} : ${room.port}' : 'Client • Connected'),
            _infoTile(
              room.e2eeEnabled ? Icons.lock : Icons.lock_open, 'Encryption',
              room.e2eeEnabled ? 'End-to-End Encrypted (AES-256)' : 'No encryption',
              iconColor: room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
            ),
            _infoTile(Icons.person, 'Display Name', myName),
            _infoTile(Icons.people, 'Participants', '${participantCount + 1} (including you)',
                iconColor: hasParticipants ? Colors.blueAccent : Colors.orangeAccent),

            // Participant list
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _participantRow(myName, isYou: true),
                  ...participantNames.map((name) => _participantRow(name)),
                  if (!hasParticipants)
                    const Padding(
                      padding: EdgeInsets.only(left: 44, top: 4),
                      child: Text('No one else is here yet...', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),

            if (isHost && localIp != null) ...[
              const SizedBox(height: 20),
              const Text('Share this room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Others can scan this QR code to join:', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(
                    data: jsonEncode({
                      'ip': localIp,
                      'e2ee': room.e2eeEnabled,
                      'room': room.name,
                      'port': room.port,
                    }),
                    version: QrVersions.auto, size: 180.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('IP: $localIp:${room.port}', style: const TextStyle(color: Colors.grey, fontSize: 13))),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

Widget _participantRow(String name, {bool isYou = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          isYou ? '$name (You)' : name,
          style: TextStyle(color: isYou ? Colors.white70 : Colors.white, fontSize: 14),
        ),
      ],
    ),
  );
}

Widget _infoTile(IconData icon, String label, String value, {Color iconColor = Colors.blueAccent}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ],
    ),
  );
}
