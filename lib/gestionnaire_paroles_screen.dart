import 'package:flutter/material.dart';

import 'lyrics_manager_screen.dart';
import 'mes_conversations_screen.dart';
import 'repetitions_screen.dart';

/// Accueil du gestionnaire de paroles : c'est aussi un choriste, il a donc
/// les onglets d'un membre (répétitions, excuses) en plus de la gestion des
/// chansons.
class GestionnaireParolesScreen extends StatefulWidget {
  const GestionnaireParolesScreen({super.key});

  @override
  State<GestionnaireParolesScreen> createState() =>
      _GestionnaireParolesScreenState();
}

class _GestionnaireParolesScreenState extends State<GestionnaireParolesScreen> {
  int _index = 0;

  static const _ecrans = [
    RepetitionsScreen(role: 'lyrics_manager'),
    LyricsManagerScreen(),
    MesConversationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ecrans[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Répétitions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
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
