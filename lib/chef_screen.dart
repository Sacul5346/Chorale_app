import 'package:flutter/material.dart';
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
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
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
        ],
      ),
    );
  }
}