import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class GestionUtilisateursScreen extends StatefulWidget {
  const GestionUtilisateursScreen({super.key});

  @override
  State<GestionUtilisateursScreen> createState() =>
      _GestionUtilisateursScreenState();
}

class _GestionUtilisateursScreenState
    extends State<GestionUtilisateursScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des membres'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          // Grouper les utilisateurs par voix
          final Map<String, List<QueryDocumentSnapshot>> groupedByVoix = {
            'chef': [],
            'soprano': [],
            'alto': [],
            'tenor': [],
            'basse': [],
            'non_definie': [],
          };

          for (var user in users) {
            final data = user.data() as Map<String, dynamic>;
            final role = data['role'] ?? 'membre';

            // Le chef a sa propre catégorie, peu importe sa voix
            if (role == 'chef') {
              groupedByVoix['chef']!.add(user);
              continue;
            }

            final voix = data.containsKey('voix') ? data['voix'] : 'non_definie';
            if (groupedByVoix.containsKey(voix)) {
              groupedByVoix[voix]!.add(user);
            } else {
              groupedByVoix['non_definie']!.add(user);
            }
          }

          final voixLabels = {
            'chef': 'Chef de chorale',
            'soprano': 'Soprano (1ère voix)',
            'alto': 'Alto (2ème voix)',
            'tenor': 'Ténor (3ème voix)',
            'basse': 'Basse',
            'non_definie': 'Voix non définie',
          };

          return ListView(
            padding: const EdgeInsets.all(12),
            children: voixLabels.entries.map((entry) {
              final voixKey = entry.key;
              final voixLabel = entry.value;
              final membersInVoix = groupedByVoix[voixKey]!;

              if (membersInVoix.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                    child: Text(
                      '$voixLabel (${membersInVoix.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  ...membersInVoix.map((user) {
                    final role = user['role'] ?? 'membre';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(role),
                          backgroundImage:
                              user.data().toString().contains('photoBase64') &&
                                      user['photoBase64'] != null
                                  ? MemoryImage(
                                      base64Decode(user['photoBase64']))
                                  : null,
                          child: !(user
                                      .data()
                                      .toString()
                                      .contains('photoBase64') &&
                                  user['photoBase64'] != null)
                              ? Text(
                                  (user['Nom'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(user['Nom'] ?? 'Sans nom'),
                        subtitle: Text(user['email'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                role,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor: _roleColor(role),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditDialog(context, user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, user.id, user['Nom']),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => _showCreateUserDialog(context),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'chef':
        return Colors.deepPurple;
      case 'responsable':
        return Colors.orange;
      case 'lyrics_manager':
        return Colors.teal;
      default:
        return Colors.teal;
    }
  }

  void _confirmDelete(BuildContext context, String userId, String nom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: Text(
          'Voulez-vous vraiment supprimer $nom ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$nom a été supprimé.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, QueryDocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final nomController = TextEditingController(text: data['Nom'] ?? '');
    String selectedRole = data['role'] ?? 'membre';
    String selectedVoix = data['voix'] ?? 'soprano';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier le membre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'membre', child: Text('Membre')),
                    DropdownMenuItem(
                      value: 'responsable',
                      child: Text('Responsable'),
                    ),
                    DropdownMenuItem(value: 'chef', child: Text('Chef')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                const SizedBox(height: 12),
                if (selectedRole != 'chef')
                  DropdownButtonFormField<String>(
                    initialValue: selectedVoix,
                    decoration: const InputDecoration(
                      labelText: 'Voix',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'soprano',
                        child: Text('Soprano (1ère voix)'),
                      ),
                      DropdownMenuItem(
                        value: 'alto',
                        child: Text('Alto (2ème voix)'),
                      ),
                      DropdownMenuItem(
                        value: 'tenor',
                        child: Text('Ténor (3ème voix)'),
                      ),
                      DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedVoix = value!);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final updateData = {
                  'Nom': nomController.text.trim(),
                  'role': selectedRole,
                };
                if (selectedRole != 'chef') {
                  updateData['voix'] = selectedVoix;
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id)
                    .update(updateData);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Membre modifié avec succès !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'membre';
    String selectedVoix = 'soprano';
    bool isLoading = false;
    String errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouveau membre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe (min 6 caractères)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'membre', child: Text('Membre')),
                    DropdownMenuItem(
                        value: 'lyrics_manager', child: Text('Gestionnaire de Lyrics')),
                    DropdownMenuItem(
                        value: 'responsable', child: Text('Responsable')),
                    DropdownMenuItem(value: 'chef', child: Text('Chef')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedVoix,
                  decoration: const InputDecoration(
                    labelText: 'Voix',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'soprano',
                      child: Text('Soprano (1ère voix)'),
                    ),
                    DropdownMenuItem(
                      value: 'alto',
                      child: Text('Alto (2ème voix)'),
                    ),
                    DropdownMenuItem(
                      value: 'tenor',
                      child: Text('Ténor (3ème voix)'),
                    ),
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedVoix = value!);
                  },
                ),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nomController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          passwordController.text.length < 6) {
                        setState(() {
                          errorMessage =
                              'Remplis tous les champs (mot de passe min 6 caractères)';
                        });
                        return;
                      }

                      setState(() {
                        isLoading = true;
                        errorMessage = '';
                      });

                      try {
                        // Le responsable sera déconnecté après cette opération
                        final secondaryApp = await Firebase.initializeApp(
                          name: 'secondary',
                          options: Firebase.app().options,
                        );

                        final secondaryAuth =
                            FirebaseAuth.instanceFor(app: secondaryApp);

                        final credential = await secondaryAuth
                            .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(credential.user!.uid)
                            .set({
                          'Nom': nomController.text.trim(),
                          'email': emailController.text.trim(),
                          'role': selectedRole,
                          'voix': selectedVoix,
                        });

                        await secondaryAuth.signOut();
                        await secondaryApp.delete();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Membre créé avec succès !'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = switch (e.code) {
                            'email-already-in-use' =>
                              'Cet email est déjà utilisé.',
                            'weak-password' =>
                              'Mot de passe trop faible.',
                            'invalid-email' => 'Email invalide.',
                            _ => 'Erreur : ${e.message}',
                          };
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
