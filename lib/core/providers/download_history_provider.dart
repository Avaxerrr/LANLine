import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/username_provider.dart';

class DownloadRecord {
  final String fileName;
  final String filePath;
  final int fileSize;
  final String senderName;
  final String roomName;
  final DateTime downloadedAt;

  DownloadRecord({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.senderName,
    required this.roomName,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'filePath': filePath,
    'fileSize': fileSize,
    'senderName': senderName,
    'roomName': roomName,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
    fileName: json['fileName'] ?? '',
    filePath: json['filePath'] ?? '',
    fileSize: json['fileSize'] ?? 0,
    senderName: json['senderName'] ?? 'Unknown',
    roomName: json['roomName'] ?? 'Unknown',
    downloadedAt: DateTime.tryParse(json['downloadedAt'] ?? '') ?? DateTime.now(),
  );

  bool get fileExists => File(filePath).existsSync();
}

final downloadHistoryProvider =
    NotifierProvider<DownloadHistoryNotifier, List<DownloadRecord>>(DownloadHistoryNotifier.new);

class DownloadHistoryNotifier extends Notifier<List<DownloadRecord>> {
  static const _storageKey = 'download_history';

  @override
  List<DownloadRecord> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      final list = jsonDecode(jsonStr) as List;
      state = list.map((e) => DownloadRecord.fromJson(e)).toList()
        ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    }
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  Future<void> addRecord(DownloadRecord record) async {
    state = [record, ...state];
    await _persist();
  }

  Future<void> deleteRecord(int index) async {
    final record = state[index];
    // Delete the actual file if it exists
    final file = File(record.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    state = [...state]..removeAt(index);
    await _persist();
  }

  Future<void> clearAll() async {
    // Delete all files
    for (final record in state) {
      final file = File(record.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    state = [];
    await _persist();
  }
}
