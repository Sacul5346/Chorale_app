import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'chef_screen.dart';
import 'responsable_screen.dart';
import 'membre_screen.dart';
import 'lyrics_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chorale App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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

        // Connecté → on récupère son rôle pour rediriger
        final uid = authSnapshot.data!.uid;
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              return const _CompteBloque(
                message: 'Impossible de charger votre profil. '
                    'Vérifiez votre connexion internet.',
              );
            }

            // Connecté mais sans fiche : on ne renvoie pas vers le login
            // (la personne resterait connectée et bloquée en boucle).
            final data = roleSnapshot.data?.data() as Map<String, dynamic>?;
            if (data == null) {
              return const _CompteBloque(
                message: 'Compte introuvable. Contactez le responsable '
                    'de la chorale.',
              );
            }
            if (data['actif'] == false) {
              return const _CompteBloque(
                message: 'Votre compte a été désactivé. Contactez le '
                    'responsable de la chorale.',
              );
            }

            final role = data['role'];

            switch (role) {
              case 'chef':
                return const ChefScreen();
              case 'responsable':
                return const ResponsableScreen();
              case 'lyrics_manager':
                return const LyricsManagerScreen();
              default:
                return const MembreScreen();
            }
          },
        );
      },
    );
  }
}

/// Écran affiché quand la personne est connectée mais ne peut pas entrer
/// (fiche absente ou compte désactivé). Seule action : se déconnecter.
class _CompteBloque extends StatelessWidget {
  final String message;
  const _CompteBloque({required this.message});

  @override
  Widget build(BuildContext context) {
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
