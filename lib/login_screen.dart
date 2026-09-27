import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme.dart';

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
          'wrong-password' => 'Email ou mot de passe incorrect.',
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
      setState(
        () => _errorMessage =
            'Saisissez votre email, puis appuyez sur « Mot de passe oublié ».',
      );
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
            'vient d\'être envoyé. Pensez à regarder dans les spams.',
          ),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CouleursChorale.aubergine, CouleursChorale.aubergineFonce],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Emblème
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: CouleursChorale.or, width: 2),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: const Icon(
                        Icons.queue_music,
                        size: 48,
                        color: CouleursChorale.or,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Nom de la chorale
                    const Text(
                      'K.T.K.F.A',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kristiana Tanora Kerobima\nFiadanana Andranovory',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Verset de la chorale
                    Container(
                      width: 48,
                      height: 1.5,
                      color: CouleursChorale.or,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '« Hitory ny anaranao amin’ny rahalahiko aho »',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CouleursChorale.or,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Formulaire
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Connexion',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _isLoading ? null : _login(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Se connecter',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _isLoading ? null : _motDePasseOublie,
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
