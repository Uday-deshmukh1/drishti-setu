import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sos_confirm_screen.dart';

class PilgrimMenuScreen extends StatefulWidget {
  const PilgrimMenuScreen({super.key});

  @override
  State<PilgrimMenuScreen> createState() => _PilgrimMenuScreenState();
}

class _PilgrimMenuScreenState extends State<PilgrimMenuScreen> {
  final FlutterTts _tts = FlutterTts();
  String _langCode = 'en';

  static const Map<String, Map<String, String>> _labels = {
    'medical': {
      'en': 'Medical Help',
      'hi': 'चिकित्सा सहायता',
      'mr': 'वैद्यकीय मदत',
    },
    'volunteer': {
      'en': 'Meet a Volunteer',
      'hi': 'स्वयंसेवक से मिलें',
      'mr': 'स्वयंसेवकाशी भेटा',
    },
    'water': {
      'en': 'Water / Food',
      'hi': 'पानी / खाना',
      'mr': 'पाणी / अन्न',
    },
    'lost': {
      'en': "I'm Lost",
      'hi': 'मैं खो गया हूँ',
      'mr': 'मी हरवलो आहे',
    },
  };

  static const Map<String, String> _speechMap = {
    'en': 'Help is on the way. Please wait.',
    'hi': 'मदद आ रही है। कृपया प्रतीक्षा करें।',
    'mr': 'मदत येत आहे. कृपया थांबा.',
  };

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _onTap(String issueType) async {
    final label = _labels[issueType]![_langCode] ?? _labels[issueType]!['en']!;
    await _tts.setLanguage(_langCode == 'hi' ? 'hi-IN' : _langCode == 'mr' ? 'mr-IN' : 'en-IN');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(label);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOSConfirmScreen(
          issueType: issueType,
          langCode: _langCode,
          speechText: _speechMap[_langCode] ?? _speechMap['en']!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text('Drishti Setu', style: TextStyle(fontSize: 26)),
        centerTitle: true,
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
                children: [
                  _menuButton(
                    onTap: () => _onTap('medical'),
                    icon: Icons.medical_services,
                    label: _labels['medical']![_langCode]!,
                    color: const Color(0xFFC62828),
                  ),
                  _menuButton(
                    onTap: () => _onTap('volunteer'),
                    icon: Icons.person,
                    label: _labels['volunteer']![_langCode]!,
                    color: const Color(0xFFEF6C00),
                  ),
                  _menuButton(
                    onTap: () => _onTap('water'),
                    icon: Icons.water_drop,
                    label: _labels['water']![_langCode]!,
                    color: const Color(0xFF1565C0),
                  ),
                  _menuButton(
                    onTap: () => _onTap('lost'),
                    icon: Icons.explore,
                    label: _labels['lost']![_langCode]!,
                    color: const Color(0xFFF9A825),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
