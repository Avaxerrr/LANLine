import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import 'username_provider.dart'; // for sharedPreferencesProvider

const _storageKey = 'lanline_rooms';

class RoomListNotifier extends Notifier<List<Room>> {
  @override
  List<Room> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return Room.deserialize(raw);
    } catch (_) {
      return [];
    }
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_storageKey, Room.serialize(state));
  }

  Room createRoom({
    required String name,
    bool e2eeEnabled = false,
    String? password,
    int port = 55556,
    String? bindAddress,
  }) {
    final room = Room(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      e2eeEnabled: e2eeEnabled,
      password: e2eeEnabled ? password : null,
      port: port,
      bindAddress: bindAddress,
      createdAt: DateTime.now(),
    );
    state = [...state, room];
    _persist();
    return room;
  }

  void updateRoom(String id, {
    String? name,
    bool? e2eeEnabled,
    String? password,
    bool clearPassword = false,
    int? port,
    String? bindAddress,
    bool clearBindAddress = false,
  }) {
    state = [
      for (final room in state)
        if (room.id == id)
          room.copyWith(
            name: name,
            e2eeEnabled: e2eeEnabled,
            password: password,
            clearPassword: clearPassword,
            port: port,
            bindAddress: bindAddress,
            clearBindAddress: clearBindAddress,
          )
        else
          room,
    ];
    _persist();
  }

  void deleteRoom(String id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  Room? getRoomById(String id) {
    try {
      return state.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

final roomListProvider = NotifierProvider<RoomListNotifier, List<Room>>(() {
  return RoomListNotifier();
});
