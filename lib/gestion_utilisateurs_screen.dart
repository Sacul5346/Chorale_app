import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'activite.dart' show genreSelonVoix;
import 'anniversaires.dart';
import 'badge.dart';
import 'roles.dart';
import 'theme.dart';

class GestionUtilisateursScreen extends StatefulWidget {
  const GestionUtilisateursScreen({super.key});

  @override
  State<GestionUtilisateursScreen> createState() =>
      _GestionUtilisateursScreenState();
}

class _GestionUtilisateursScreenState extends State<GestionUtilisateursScreen> {
  /// Dernière liste reçue, pour imprimer tous les badges sans relire la base.
  List<QueryDocumentSnapshot> _derniereListe = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des membres'),
        actions: [
          IconButton(
            tooltip: 'Imprimer les badges de tous les membres',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => _imprimerTousLesBadges(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;
          _derniereListe = users;
          final monUid = FirebaseAuth.instance.currentUser?.uid;
          final maintenant = DateTime.now();

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
            final role = roleNormalise(data['role']);

            // Le chef a sa propre catégorie, peu importe sa voix
            if (role == 'chef') {
              groupedByVoix['chef']!.add(user);
              continue;
            }

            final voix = data.containsKey('voix')
                ? data['voix']
                : 'non_definie';
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
                    final data = user.data() as Map<String, dynamic>;
                    final role = roleNormalise(data['role']);
                    final suppleant = estSuppleant(data, maintenant);
                    final moiMeme = user.id == monUid;
                    final nomBrut = data['Nom'];
                    final nom = nomBrut is String && nomBrut.trim().isNotEmpty
                        ? nomBrut.trim()
                        : 'Sans nom';
                    final photo = data['photoBase64'];
                    final actif = data['actif'] != false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: actif ? null : Colors.grey.shade200,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: actif
                              ? _roleColor(role)
                              : Colors.grey,
                          backgroundImage: photo is String && photo.isNotEmpty
                              ? MemoryImage(base64Decode(photo))
                              : null,
                          child: photo is String && photo.isNotEmpty
                              ? null
                              : Text(
                                  nom[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                        title: Text(
                          nom,
                          style: actif
                              ? null
                              : const TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                        ),
                        subtitle: Text(
                          !actif
                              ? 'Compte désactivé'
                              : suppleant
                              ? 'Suppléant jusqu\'au '
                                    '${_date(_dernierJour(finSuppleance(data)!))}'
                              : (data['email'] as String? ?? ''),
                          style: suppleant && actif
                              ? const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                suppleant ? 'Suppléant' : _roleLabel(role),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: !actif
                                  ? Colors.grey
                                  : suppleant
                                  ? Colors.deepOrange
                                  : _roleColor(role),
                              visualDensity: VisualDensity.compact,
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              onSelected: (choix) => switch (choix) {
                                'modifier' => _showEditDialog(
                                  context,
                                  user,
                                  moiMeme: moiMeme,
                                ),
                                'suppleant' => _nommerSuppleant(
                                  context,
                                  user.id,
                                  nom,
                                  finSuppleance(data),
                                ),
                                'arreter' => _arreterSuppleance(
                                  context,
                                  user.id,
                                  nom,
                                ),
                                'badge' => BadgesScreen.ouvrir(context, [
                                  BadgeMembre.depuisFiche(user.id, data),
                                ]),
                                'desactiver' => _confirmDesactivation(
                                  context,
                                  user.id,
                                  nom,
                                ),
                                _ => _setActif(context, user.id, nom, true),
                              },
                              itemBuilder: (_) => [
                                _entree('modifier', Icons.edit, 'Modifier'),
                                if (actif)
                                  _entree(
                                    'badge',
                                    Icons.qr_code_2,
                                    'Imprimer le badge',
                                  ),
                                if (actif && role != 'chef') ...[
                                  _entree(
                                    'suppleant',
                                    Icons.badge_outlined,
                                    suppleant
                                        ? 'Changer la date de fin'
                                        : 'Nommer suppléant',
                                  ),
                                  if (suppleant)
                                    _entree(
                                      'arreter',
                                      Icons.event_busy,
                                      'Arrêter la suppléance',
                                    ),
                                ],
                                // On ne se désactive pas soi-même.
                                if (actif && !moiMeme)
                                  _entree(
                                    'desactiver',
                                    Icons.person_off_outlined,
                                    'Désactiver',
                                  )
                                else if (!actif)
                                  _entree(
                                    'reactiver',
                                    Icons.person_add_alt_1,
                                    'Réactiver',
                                  ),
                              ],
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

  Color _roleColor(String role) => switch (role) {
    'chef' => CouleursChorale.aubergine,
    'lyrics_manager' => Colors.indigo,
    _ => Colors.teal,
  };

  String _roleLabel(String role) => switch (role) {
    'chef' => 'Chef',
    'lyrics_manager' => 'Paroles',
    _ => 'Membre',
  };

  PopupMenuItem<String> _entree(String valeur, IconData icone, String texte) =>
      PopupMenuItem(
        value: valeur,
        child: Row(
          children: [
            Icon(icone, size: 20),
            const SizedBox(width: 12),
            Text(texte),
          ],
        ),
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Dernier jour inclus d'une suppléance (la fin est le lendemain à minuit).
  static DateTime _dernierJour(DateTime fin) =>
      fin.subtract(const Duration(minutes: 1));

  /// Rôles proposés. L'ancien rôle « responsable » n'existe plus : pendant
  /// une absence, le chef nomme un suppléant (menu ⋮ du membre).
  Widget _choixRole(String role, ValueChanged<String> onChange) =>
      DropdownButtonFormField<String>(
        initialValue: role,
        decoration: const InputDecoration(
          labelText: 'Rôle',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'membre', child: Text('Membre')),
          DropdownMenuItem(
            value: 'lyrics_manager',
            child: Text('Gestionnaire de Lyrics'),
          ),
          DropdownMenuItem(value: 'chef', child: Text('Chef')),
        ],
        onChanged: (value) => onChange(value!),
      );

  // ---------------- Badges ----------------

  void _imprimerTousLesBadges(BuildContext context) {
    const ordre = ['chef', 'soprano', 'alto', 'tenor', 'basse'];
    int rang(Map<String, dynamic> d) {
      final cle = roleNormalise(d['role']) == 'chef' ? 'chef' : d['voix'];
      final i = ordre.indexOf(cle is String ? cle : '');
      return i < 0 ? ordre.length : i;
    }

    final fiches = [
      for (final u in _derniereListe)
        if ((u.data() as Map<String, dynamic>)['actif'] != false)
          (id: u.id, data: u.data() as Map<String, dynamic>),
    ];
    if (fiches.isEmpty) return;
    fiches.sort((a, b) {
      final r = rang(a.data).compareTo(rang(b.data));
      if (r != 0) return r;
      return '${a.data['Nom'] ?? ''}'.toLowerCase().compareTo(
        '${b.data['Nom'] ?? ''}'.toLowerCase(),
      );
    });
    BadgesScreen.ouvrir(context, [
      for (final f in fiches) BadgeMembre.depuisFiche(f.id, f.data),
    ]);
  }

  /// Juste après la création d'un compte : imprimer son badge tout de suite.
  void _proposerBadge(BuildContext context, BadgeMembre membre) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('Membre créé !'),
        content: Text(
          'Voulez-vous imprimer le badge de ${membre.nom} maintenant ? '
          'Vous pourrez aussi le faire plus tard depuis le menu ⋮ du membre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Plus tard'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Voir le badge'),
            onPressed: () {
              Navigator.pop(dialogContext);
              BadgesScreen.ouvrir(context, [membre]);
            },
          ),
        ],
      ),
    );
  }

  // ---------------- Suppléance ----------------

  /// Le chef choisit le dernier jour de son absence : le membre a les
  /// pouvoirs de gestion (sauf les comptes) jusqu'à la fin de ce jour.
  Future<void> _nommerSuppleant(
    BuildContext context,
    String userId,
    String nom,
    DateTime? finActuelle,
  ) async {
    final aujourdhui = DateTime.now();
    final debut = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    final proposition = finActuelle != null && finActuelle.isAfter(aujourdhui)
        ? _dernierJour(finActuelle)
        : debut.add(const Duration(days: 7));
    final dernierJour = await showDatePicker(
      context: context,
      helpText: 'Dernier jour de suppléance de $nom',
      initialDate: proposition,
      firstDate: debut,
      lastDate: debut.add(const Duration(days: 365)),
    );
    if (dernierJour == null || !context.mounted) return;

    await _modifierFiche(context, userId, {
      champSuppleance: Timestamp.fromDate(finPourDernierJour(dernierJour)),
    }, '$nom remplace le chef jusqu\'au ${_date(dernierJour)} inclus.');
  }

  Future<void> _arreterSuppleance(
    BuildContext context,
    String userId,
    String nom,
  ) => _modifierFiche(context, userId, {
    champSuppleance: FieldValue.delete(),
  }, 'La suppléance de $nom est terminée.');

  Future<void> _modifierFiche(
    BuildContext context,
    String userId,
    Map<String, Object> champs,
    String messageSucces,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(champs);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageSucces), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // On désactive au lieu de supprimer : effacer le compte de connexion
  // (Firebase Auth) d'une autre personne est impossible depuis l'app.
  // Un compte désactivé est bloqué par AuthGate (main.dart).
  Future<void> _setActif(
    BuildContext context,
    String userId,
    String nom,
    bool actif,
  ) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'actif': actif,
    });
    await activerAnniversaire(userId, actif).catchError((_) {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actif ? '$nom a été réactivé.' : '$nom a été désactivé.',
          ),
          backgroundColor: actif ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _confirmDesactivation(BuildContext context, String userId, String nom) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Désactiver ce membre ?'),
        content: Text(
          '$nom ne pourra plus se connecter. Son historique est conservé, '
          'et vous pourrez le réactiver plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _setActif(context, userId, nom, false);
            },
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
  }

  /// [moiMeme] : le chef modifie sa propre fiche ; il ne peut pas changer
  /// son propre rôle (la chorale se retrouverait sans chef).
  Future<void> _showEditDialog(
    BuildContext context,
    QueryDocumentSnapshot user, {
    required bool moiMeme,
  }) async {
    final data = user.data() as Map<String, dynamic>;
    final anniversaire = await lireAnniversaire(
      user.id,
    ).catchError((_) => null);
    if (!context.mounted) return;
    int? jourNaissance = anniversaire?.jour;
    int? moisNaissance = anniversaire?.mois;
    var anniversaireModifie = false;
    final nomController = TextEditingController(text: data['Nom'] ?? '');
    // L'ancien rôle « responsable » devient « membre ».
    const voix = ['soprano', 'alto', 'tenor', 'basse'];
    String selectedRole = roleNormalise(data['role']);
    String selectedVoix = voix.contains(data['voix'])
        ? data['voix'] as String
        : 'soprano';
    // Genre (classement des membres du mois) : proposé selon la voix.
    String? selectedGenre = data['genre'] == 'homme' || data['genre'] == 'femme'
        ? data['genre'] as String
        : genreSelonVoix(data['voix']);

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
                if (!moiMeme) ...[
                  const SizedBox(height: 12),
                  _choixRole(
                    selectedRole,
                    (value) => setState(() => selectedRole = value),
                  ),
                ],
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
                if (selectedRole != 'chef') ...[
                  const SizedBox(height: 12),
                  _choixGenre(
                    selectedGenre,
                    (g) => setState(() => selectedGenre = g),
                  ),
                ],
                const SizedBox(height: 12),
                ChampAnniversaire(
                  jour: jourNaissance,
                  mois: moisNaissance,
                  onChange: (jour, mois) => setState(() {
                    jourNaissance = jour;
                    moisNaissance = mois;
                    anniversaireModifie = true;
                  }),
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
                final updateData = <String, Object>{
                  'Nom': nomController.text.trim(),
                  'role': selectedRole,
                };
                // Un nouveau chef n'a plus besoin de suppléance.
                if (selectedRole == 'chef') {
                  updateData[champSuppleance] = FieldValue.delete();
                }
                if (selectedRole != 'chef') {
                  updateData['voix'] = selectedVoix;
                  if (selectedGenre != null) {
                    updateData['genre'] = selectedGenre!;
                  }
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id)
                    .update(updateData);
                if (anniversaireModifie || jourNaissance != null) {
                  await enregistrerAnniversaire(
                    user.id,
                    nomController.text.trim(),
                    jourNaissance,
                    moisNaissance,
                  );
                }

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
    String? selectedGenre = genreSelonVoix('soprano');
    var genreChoisiALaMain = false;
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
                _choixRole(
                  selectedRole,
                  (value) => setState(() => selectedRole = value),
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
                    setState(() {
                      selectedVoix = value!;
                      if (!genreChoisiALaMain) {
                        selectedGenre = genreSelonVoix(selectedVoix);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                _choixGenre(
                  selectedGenre,
                  (g) => setState(() {
                    selectedGenre = g;
                    genreChoisiALaMain = true;
                  }),
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

                      // Une app Firebase secondaire crée le compte sans
                      // déconnecter le chef. Elle est toujours
                      // supprimée à la fin, sinon la création suivante
                      // échouerait (« duplicate-app »).
                      FirebaseApp? secondaryApp;
                      try {
                        secondaryApp =
                            Firebase.apps
                                .where((app) => app.name == 'secondary')
                                .firstOrNull ??
                            await Firebase.initializeApp(
                              name: 'secondary',
                              options: Firebase.app().options,
                            );

                        final secondaryAuth = FirebaseAuth.instanceFor(
                          app: secondaryApp,
                        );

                        final credential = await secondaryAuth
                            .createUserWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );

                        final fiche = <String, dynamic>{
                          'Nom': nomController.text.trim(),
                          'email': emailController.text.trim(),
                          'role': selectedRole,
                          'voix': selectedVoix,
                          'genre': ?selectedGenre,
                        };
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(credential.user!.uid)
                            .set(fiche);

                        await secondaryAuth.signOut();

                        if (context.mounted) {
                          Navigator.pop(context);
                          // Contexte de l'écran : celui du dialogue est fermé.
                          if (mounted) {
                            _proposerBadge(
                              this.context,
                              BadgeMembre.depuisFiche(
                                credential.user!.uid,
                                fiche,
                              ),
                            );
                          }
                        }
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = switch (e.code) {
                            'email-already-in-use' =>
                              'Cet email est déjà utilisé.',
                            'weak-password' => 'Mot de passe trop faible.',
                            'invalid-email' => 'Email invalide.',
                            'network-request-failed' =>
                              'Pas de connexion internet.',
                            _ => 'Erreur : ${e.message}',
                          };
                        });
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = 'Erreur : $e';
                        });
                      } finally {
                        await secondaryApp?.delete();
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

  /// Genre du membre : sert à désigner un homme et une femme « membres du
  /// mois ».
  static Widget _choixGenre(String? valeur, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      // La clé force l'affichage de la nouvelle valeur quand elle est
      // proposée automatiquement (changement de voix).
      key: ValueKey(valeur),
      initialValue: valeur,
      decoration: const InputDecoration(
        labelText: 'Genre (membres du mois)',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'femme', child: Text('Femme')),
        DropdownMenuItem(value: 'homme', child: Text('Homme')),
      ],
      onChanged: onChanged,
    );
  }
}
