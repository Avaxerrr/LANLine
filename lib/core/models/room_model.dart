import 'dart:convert';

class Room {
  final String id;
  String name;
  bool e2eeEnabled;
  String? password;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    this.e2eeEnabled = false,
    this.password,
    required this.createdAt,
  });

  Room copyWith({
    String? name,
    bool? e2eeEnabled,
    String? password,
    bool clearPassword = false,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      e2eeEnabled: e2eeEnabled ?? this.e2eeEnabled,
      password: clearPassword ? null : (password ?? this.password),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'e2eeEnabled': e2eeEnabled,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String,
    name: json['name'] as String,
    e2eeEnabled: json['e2eeEnabled'] as bool? ?? false,
    password: json['password'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String serialize(List<Room> rooms) =>
      jsonEncode(rooms.map((r) => r.toJson()).toList());

  static List<Room> deserialize(String json) =>
      (jsonDecode(json) as List).map((e) => Room.fromJson(e)).toList();
}
