import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Pas besoin de naviguer manuellement —
      // AuthGate va automatiquement détecter la connexion et rediriger
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          // Les SDK récents renvoient « invalid-credential » au lieu de
          // « user-not-found » / « wrong-password » (protection anti-énumération).
          'invalid-credential' ||
          'user-not-found' ||
          'wrong-password' =>
            'Email ou mot de passe incorrect.',
          'invalid-email' => 'Email invalide.',
          'user-disabled' => 'Ce compte a été désactivé.',
          'too-many-requests' =>
            'Trop de tentatives. Patientez quelques minutes.',
          'network-request-failed' => 'Pas de connexion internet.',
          _ => 'Erreur de connexion. Réessayez.',
        };
      });
    } finally {
      // Après une connexion réussie, AuthGate a déjà remplacé cet écran.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _motDePasseOublie() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage =
          'Saisissez votre email, puis appuyez sur « Mot de passe oublié ».');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _errorMessage = '');
      // Message identique que le compte existe ou non (confidentialité).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Si un compte existe pour $email, un email de réinitialisation '
              'vient d\'être envoyé. Pensez à regarder dans les spams.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          'invalid-email' => 'Email invalide.',
          'network-request-failed' => 'Pas de connexion internet.',
          _ => 'Impossible d\'envoyer l\'email. Réessayez.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Icône
              const Icon(
                Icons.music_note,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chorale App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connectez-vous pour continuer',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Champ email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Champ mot de passe
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Message d'erreur
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),

              // Bouton connexion
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Se connecter', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _motDePasseOublie,
                child: const Text('Mot de passe oublié ?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}