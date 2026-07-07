import 'package:flutter/material.dart';
import 'repetitions_screen.dart';
import 'mes_conversations_screen.dart';
import 'songs_screen.dart';

class MembreScreen extends StatefulWidget {
  const MembreScreen({super.key});

  @override
  State<MembreScreen> createState() => _MembreScreenState();
}

class _MembreScreenState extends State<MembreScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const RepetitionsScreen(role: 'membre'),
      const SongsScreen(role: 'membre'),
      const MesConversationsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey[700],
        backgroundColor: Colors.white,
        elevation: 8,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Mes excuses',
          ),
        ],
      ),
    );
  }
}