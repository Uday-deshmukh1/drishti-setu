import 'package:flutter/material.dart';
import 'role_select_screen.dart';

void main() {
  runApp(const DrishtiSetuApp());
}

class DrishtiSetuApp extends StatelessWidget {
  const DrishtiSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drishti Setu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE65100)),
        useMaterial3: true,
      ),
      home: const RoleSelectScreen(),
    );
  }
}
