import 'package:flutter/material.dart';
import 'messages_screen.dart';
import 'repetitions_screen.dart';
import 'songs_screen.dart';

class ChefScreen extends StatefulWidget {
  const ChefScreen({super.key});

  @override
  State<ChefScreen> createState() => _ChefScreenState();
}

class _ChefScreenState extends State<ChefScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const RepetitionsScreen(role: 'chef'),
      const SongsScreen(role: 'chef'),
      const MessagesScreen(marquerLu: false),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Répétitions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Chansons',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Excuses'),
        ],
      ),
    );
  }
}
