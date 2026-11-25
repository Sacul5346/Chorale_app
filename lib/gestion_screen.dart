import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gestion_utilisateurs_screen.dart';
import 'messages_screen.dart';
import 'repetitions_screen.dart';
import 'songs_screen.dart';

/// Accueil de la direction : le chef, ou son suppléant pendant une absence.
///
/// Le suppléant a les mêmes écrans que le chef, sauf la gestion des membres
/// (comptes, rôles, suppléances), qui reste au seul chef.
class GestionScreen extends StatefulWidget {
  final bool estChef;

  /// Fin de la suppléance, affichée au suppléant (null pour le chef).
  final DateTime? finSuppleance;

  const GestionScreen({super.key, required this.estChef, this.finSuppleance});

  @override
  State<GestionScreen> createState() => _GestionScreenState();
}

class _GestionScreenState extends State<GestionScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Les écrans communs reçoivent le rôle « chef » : le suppléant y a
    // exactement les pouvoirs du chef.
    final screens = [
      const RepetitionsScreen(role: 'chef'),
      const SongsScreen(role: 'chef'),
      if (widget.estChef) const GestionUtilisateursScreen(),
      const MessagesScreen(),
    ];
    final index = _currentIndex.clamp(0, screens.length - 1);

    return StreamBuilder<QuerySnapshot>(
      // Badge : excuses pas encore lues par la direction.
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('unreadByResponsable', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final fin = widget.finSuppleance;

        return Scaffold(
          body: Column(
            children: [
              if (fin != null) _BandeauSuppleance(fin: fin),
              Expanded(
                // Le bandeau occupe déjà la marge du haut (encoche).
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: fin != null,
                  child: screens[index],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _currentIndex = i),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Répétitions',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.music_note),
                label: 'Chansons',
              ),
              if (widget.estChef)
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
                label: 'Excuses',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rappelle au suppléant qu'il remplace le chef, et jusqu'à quand.
class _BandeauSuppleance extends StatelessWidget {
  final DateTime fin;
  const _BandeauSuppleance({required this.fin});

  @override
  Widget build(BuildContext context) {
    // La fin est le lendemain à minuit : on affiche le dernier jour inclus.
    final dernierJour = fin.subtract(const Duration(minutes: 1));
    final date =
        '${dernierJour.day.toString().padLeft(2, '0')}/'
        '${dernierJour.month.toString().padLeft(2, '0')}/${dernierJour.year}';
    return Material(
      color: Colors.amber.shade100,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vous remplacez le chef jusqu\'au $date inclus.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
