import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class SOSConfirmScreen extends StatefulWidget {
  final String issueType;
  final String langCode;
  final String speechText;

  const SOSConfirmScreen({
    super.key,
    required this.issueType,
    required this.langCode,
    required this.speechText,
  });

  @override
  State<SOSConfirmScreen> createState() => _SOSConfirmScreenState();
}

class _SOSConfirmScreenState extends State<SOSConfirmScreen> {
  bool _loading = true;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendSOS();
  }

  Future<void> _sendSOS() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await ApiService.sendSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        issueType: widget.issueType,
        language: widget.langCode,
      );

      setState(() {
        _success = true;
        _loading = false;
      });

      final tts = FlutterTts();
      await tts.setLanguage(
        widget.langCode == 'hi'
            ? 'hi-IN'
            : widget.langCode == 'mr'
                ? 'mr-IN'
                : 'en-IN',
      );
      await tts.setSpeechRate(0.5);
      await tts.speak(widget.speechText);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Widget content;

    if (_loading) {
      bgColor = Colors.white;
      content = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 4),
          SizedBox(height: 24),
          Text(
            'Sending SOS...',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (_success) {
      bgColor = const Color(0xFF2E7D32);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 120, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            widget.langCode == 'hi'
                ? 'मदद आ रही है'
                : widget.langCode == 'mr'
                    ? 'मदत येत आहे'
                    : 'Help is Coming',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.langCode == 'hi'
                ? 'कृपया प्रतीक्षा करें'
                : widget.langCode == 'mr'
                    ? 'कृपया थांबा'
                    : 'Please wait',
            style: const TextStyle(fontSize: 22, color: Colors.white70),
          ),
        ],
      );
    } else {
      bgColor = const Color(0xFFC62828);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 100, color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Failed to send SOS',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _sendSOS,
            icon: const Icon(Icons.refresh, size: 28),
            label: const Text('Retry', style: TextStyle(fontSize: 22)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFC62828),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: Center(child: content)),
    );
  }
}
