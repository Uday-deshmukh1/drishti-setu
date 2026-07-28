import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class VolunteerLocationService extends StatefulWidget {
  const VolunteerLocationService({super.key});

  @override
  State<VolunteerLocationService> createState() =>
      _VolunteerLocationServiceState();
}

class _VolunteerLocationServiceState extends State<VolunteerLocationService> {
  bool _sharing = false;
  Timer? _timer;
  String _volunteerId = '';
  String _volunteerName = '';
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _volunteerId = prefs.getString('volunteer_id') ?? '';
      _volunteerName = prefs.getString('volunteer_name') ?? '';
      _sharing = prefs.getBool('sharing_location') ?? false;
    });
    if (_sharing && _volunteerId.isNotEmpty) {
      _startSharing();
    }
  }

  Future<void> _toggleSharing(bool value) async {
    if (value) {
      if (_volunteerName.isEmpty) {
        await _promptName();
        if (_volunteerName.isEmpty) return;
      }
      if (_volunteerId.isEmpty) {
        _volunteerId = DateTime.now().millisecondsSinceEpoch.toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('volunteer_id', _volunteerId);
      }
      setState(() => _sharing = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sharing_location', true);
      _startSharing();
    } else {
      _timer?.cancel();
      setState(() => _sharing = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sharing_location', false);
    }
  }

  Future<void> _promptName() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Your Name'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_nameController.text.trim().isNotEmpty) {
                _volunteerName = _nameController.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('volunteer_name', _volunteerName);
                Navigator.pop(context);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startSharing() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
    _sendLocation();
  }

  Future<void> _sendLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiService.updateVolunteerLocation(
        volunteerId: _volunteerId,
        lat: pos.latitude,
        lng: pos.longitude,
        name: _volunteerName,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Location')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _sharing ? Icons.location_on : Icons.location_off,
                size: 100,
                color: _sharing ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                _sharing ? 'Sharing Active' : 'Sharing Off',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_volunteerName.isNotEmpty)
                Text(
                  'Name: $_volunteerName',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              const SizedBox(height: 32),
              SwitchListTile(
                value: _sharing,
                onChanged: _toggleSharing,
                title: Text(
                  _sharing ? 'Stop Sharing' : 'Share my location',
                  style: const TextStyle(fontSize: 22),
                ),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
