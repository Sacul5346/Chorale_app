import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gestion_utilisateurs_screen.dart';
import 'repetitions_screen.dart';
import 'messages_screen.dart';
import 'songs_screen.dart';

class ResponsableScreen extends StatefulWidget {
  const ResponsableScreen({super.key});

  @override
  State<ResponsableScreen> createState() => _ResponsableScreenState();
}

class _ResponsableScreenState extends State<ResponsableScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const RepetitionsScreen(role: 'responsable'),
      const SongsScreen(role: 'responsable'),
      const GestionUtilisateursScreen(),
      const MessagesScreen(),
    ];

    return StreamBuilder<QuerySnapshot>(
      // Badge non-lus calculé via conversations.
      // (messages_screen.dart gère déjà l’affichage des conversations)
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('unreadByResponsable', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey[700],
            backgroundColor: Colors.white,
            elevation: 8,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Répétitions',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.music_note),
                label: 'Chansons',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Membres',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  child: const Icon(Icons.message),
                ),
                label: 'Messages',
              ),
            ],
          ),
        );
      },
    );
  }
}

