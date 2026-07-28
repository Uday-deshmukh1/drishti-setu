import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pilgrim_menu_screen.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speakPrompt();
  }

  Future<void> _speakPrompt() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(
      'For English press 1. '
      'Hindi ke liye 2 dabayen. '
      'Marathisathi 3 daba.',
    );
  }

  Future<void> _selectLanguage(String langCode, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    await prefs.setString('language_label', label);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PilgrimMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.visibility, size: 80, color: Color(0xFFE65100)),
            const SizedBox(height: 16),
            const Text(
              'Drishti Setu',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your language',
              style: TextStyle(fontSize: 22, color: Colors.black87),
            ),
            const SizedBox(height: 48),
            _langButton(
              onPressed: () => _selectLanguage('en', 'English'),
              label: 'English',
              sublabel: 'Press 1',
              color: const Color(0xFF1565C0),
              icon: Icons.language,
            ),
            const SizedBox(height: 20),
            _langButton(
              onPressed: () => _selectLanguage('hi', 'हिंदी'),
              label: 'हिंदी',
              sublabel: '2 दबाएं',
              color: const Color(0xFF2E7D32),
              icon: Icons.translate,
            ),
            const SizedBox(height: 20),
            _langButton(
              onPressed: () => _selectLanguage('mr', 'मराठी'),
              label: 'मराठी',
              sublabel: '3 दाबा',
              color: const Color(0xFFAD1457),
              icon: Icons.translate,
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _langButton({
    required VoidCallback onPressed,
    required String label,
    required String sublabel,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 90,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
