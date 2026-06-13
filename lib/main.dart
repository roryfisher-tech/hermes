import 'package:flutter/material.dart';
import 'ui/chat_screen.dart';

void main() => runApp(const HermesApp());

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4C6FFF),
      ),
      home: const ChatScreen(),
    );
  }
}
