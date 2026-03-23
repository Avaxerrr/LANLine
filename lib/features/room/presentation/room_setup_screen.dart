import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/room_model.dart';
import '../../../core/providers/room_provider.dart';

class RoomSetupScreen extends ConsumerStatefulWidget {
  final Room? existingRoom;
  const RoomSetupScreen({super.key, this.existingRoom});

  @override
  ConsumerState<RoomSetupScreen> createState() => _RoomSetupScreenState();
}

class _RoomSetupScreenState extends ConsumerState<RoomSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _portController;
  late bool _e2eeEnabled;
  late String? _selectedBindAddress;
  bool _showAdvanced = false;
  List<_NetworkInterfaceInfo> _interfaces = [];

  bool get _isEditing => widget.existingRoom != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingRoom?.name ?? '');
    _passwordController = TextEditingController(text: widget.existingRoom?.password ?? '');
    _portController = TextEditingController(text: (widget.existingRoom?.port ?? 55556).toString());
    _e2eeEnabled = widget.existingRoom?.e2eeEnabled ?? false;
    _selectedBindAddress = widget.existingRoom?.bindAddress;

    // Pre-expand advanced if user had custom settings
    if (widget.existingRoom != null &&
        (widget.existingRoom!.port != 55556 || widget.existingRoom!.bindAddress != null)) {
      _showAdvanced = true;
    }

    _loadInterfaces();
  }

  Future<void> _loadInterfaces() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: true,
    );
    final result = <_NetworkInterfaceInfo>[];
    for (var iface in interfaces) {
      for (var addr in iface.addresses) {
        if (!addr.isLoopback) {
          result.add(_NetworkInterfaceInfo(name: iface.name, ip: addr.address));
        }
      }
    }
    if (mounted) {
      setState(() {
        _interfaces = result;
        // Reset bind address if the saved IP is no longer available
        if (_selectedBindAddress != null &&
            !result.any((iface) => iface.ip == _selectedBindAddress)) {
          _selectedBindAddress = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room name cannot be empty')),
      );
      return;
    }

    if (_e2eeEnabled && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a password for encryption')),
      );
      return;
    }

    final password = _e2eeEnabled ? _passwordController.text.trim() : null;
    final port = int.tryParse(_portController.text.trim()) ?? 55556;

    if (port < 1024 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port must be between 1024 and 65535')),
      );
      return;
    }

    if (_isEditing) {
      ref.read(roomListProvider.notifier).updateRoom(
        widget.existingRoom!.id,
        name: name,
        e2eeEnabled: _e2eeEnabled,
        password: password,
        clearPassword: !_e2eeEnabled,
        port: port,
        bindAddress: _selectedBindAddress,
        clearBindAddress: _selectedBindAddress == null,
      );
    } else {
      ref.read(roomListProvider.notifier).createRoom(
        name: name,
        e2eeEnabled: _e2eeEnabled,
        password: password,
        port: port,
        bindAddress: _selectedBindAddress,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Room' : 'Create Room',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Name
            const Text('Room Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 18, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Living Room, Office',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                ),
                prefixIcon: const Icon(Icons.meeting_room, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 32),

            // E2EE Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End-to-End Encryption',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                    subtitle: Text(
                      _e2eeEnabled
                          ? 'Messages encrypted with AES-256'
                          : 'Messages sent without encryption',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    value: _e2eeEnabled,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (val) => setState(() => _e2eeEnabled = val),
                  ),
                  if (_e2eeEnabled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Room Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'Shared secret for all participants',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF252525),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.key, color: Colors.greenAccent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this password with people you want to join.\nThey\'ll need it to read and send messages.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Network Settings (collapsible)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.settings_ethernet, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Network Settings',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                Text('Port, bind address (for Tailscale / WAN)',
                                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(
                            _showAdvanced ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdvanced) ...[
                    const Divider(color: Color(0xFF333333), height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Port
                          const Text('Port', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _portController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              hintText: '55556',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF252525),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.numbers, color: Colors.orangeAccent, size: 18),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Default: 55556. Change if hosting multiple rooms or for firewall rules.',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),

                          const SizedBox(height: 20),

                          // Bind Address
                          const Text('Bind Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedBindAddress,
                                dropdownColor: const Color(0xFF333333),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                hint: const Text('All Interfaces (0.0.0.0)', style: TextStyle(color: Colors.grey)),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Interfaces (0.0.0.0)', style: TextStyle(color: Colors.white)),
                                  ),
                                  ..._interfaces.map((iface) => DropdownMenuItem<String?>(
                                    value: iface.ip,
                                    child: Text('${iface.name} — ${iface.ip}', style: const TextStyle(color: Colors.white)),
                                  )),
                                ],
                                onChanged: (val) => setState(() => _selectedBindAddress = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Select your Tailscale or VPN interface to host across networks.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: Colors.blueAccent.withValues(alpha: 0.4),
                ),
                icon: Icon(_isEditing ? Icons.save : Icons.add, size: 22),
                label: Text(
                  _isEditing ? 'Save Changes' : 'Create Room',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkInterfaceInfo {
  final String name;
  final String ip;
  _NetworkInterfaceInfo({required this.name, required this.ip});
}
