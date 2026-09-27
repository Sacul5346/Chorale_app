import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'chef_screen.dart';
import 'responsable_screen.dart';
import 'membre_screen.dart';
import 'gestionnaire_paroles_screen.dart';
import 'rappels.dart';
import 'theme.dart';
import 'telechargement_web.dart'
    if (dart.library.io) 'telechargement_io.dart'
    as stockage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K.T.K.F.A',
      debugShowCheckedModeBanner: false,
      theme: themeChorale(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // En cours de vérification
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Pas connecté → écran de login
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // Connecté → on suit sa fiche en continu : une désactivation (ou un
        // changement de rôle) s'applique tout de suite, même app ouverte.
        final uid = authSnapshot.data!.uid;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, roleSnapshot) {
            if (!roleSnapshot.hasData && !roleSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              return const _CompteBloque(
                message:
                    'Impossible de charger votre profil. '
                    'Vérifiez votre connexion internet.',
              );
            }

            // Connecté mais sans fiche : on ne renvoie pas vers le login
            // (la personne resterait connectée et bloquée en boucle).
            final data = roleSnapshot.data?.data() as Map<String, dynamic>?;
            if (data == null) {
              return const _CompteBloque(
                message:
                    'Compte introuvable. Contactez le responsable '
                    'de la chorale.',
                effacerDonnees: true,
              );
            }
            if (data['actif'] == false) {
              return const _CompteBloque(
                message:
                    'Votre compte a été désactivé. Contactez le '
                    'responsable de la chorale.',
                effacerDonnees: true,
              );
            }

            final role = data['role'] as String? ?? 'membre';

            return RappelsSync(
              role: role,
              child: switch (role) {
                'chef' => const ChefScreen(),
                'responsable' => const ResponsableScreen(),
                'lyrics_manager' => const GestionnaireParolesScreen(),
                _ => const MembreScreen(),
              },
            );
          },
        );
      },
    );
  }
}

/// Écran affiché quand la personne est connectée mais ne peut pas entrer
/// (fiche absente ou compte désactivé). Seule action : se déconnecter.
class _CompteBloque extends StatefulWidget {
  final String message;

  /// Compte désactivé ou introuvable : on efface les playbacks téléchargés
  /// et les rappels programmés sur ce téléphone.
  final bool effacerDonnees;

  const _CompteBloque({required this.message, this.effacerDonnees = false});

  @override
  State<_CompteBloque> createState() => _CompteBloqueState();
}

class _CompteBloqueState extends State<_CompteBloque> {
  @override
  void initState() {
    super.initState();
    if (widget.effacerDonnees) {
      stockage.supprimerTout().catchError((_) {});
      Rappels.toutAnnuler();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
