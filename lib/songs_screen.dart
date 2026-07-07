import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class SongsScreen extends StatefulWidget {
  final String role;
  const SongsScreen({super.key, required this.role});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final _songTitleController = TextEditingController();
  final _songArtistController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedRegion = 'Tous';

  @override
  void dispose() {
    _songTitleController.dispose();
    _songArtistController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chansons'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          if (widget.role == 'chef')
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter une chanson',
              onPressed: () => _showAddSongDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une chanson...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Filtrage par région
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: ['Tous', 'Sud', 'Merina', 'Sud-Est'].map((region) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FilterChip(
                      label: Text(region),
                      selected: _selectedRegion == region,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRegion = selected ? region : 'Tous';
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Liste des chansons
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('songs')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucune chanson trouvée'),
                  );
                }

                List<DocumentSnapshot> songs = snapshot.data!.docs;

                // Filtrer par région
                if (_selectedRegion != 'Tous') {
                  songs = songs
                      .where((doc) => doc['region'] == _selectedRegion)
                      .toList();
                }

                // Filtrer par recherche
                if (_searchController.text.isNotEmpty) {
                  songs = songs
                      .where((doc) =>
                          doc['title']
                              .toLowerCase()
                              .contains(_searchController.text.toLowerCase()) ||
                          doc['artist']
                              .toLowerCase()
                              .contains(_searchController.text.toLowerCase()))
                      .toList();
                }

                // Grouper par région
                Map<String, List<DocumentSnapshot>> songsByRegion = {};
                for (var song in songs) {
                  final region = song['region'];
                  if (!songsByRegion.containsKey(region)) {
                    songsByRegion[region] = [];
                  }
                  songsByRegion[region]!.add(song);
                }

                return ListView(
                  children: songsByRegion.entries.map((entry) {
                    final region = entry.key;
                    final regionSongs = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            region,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ...regionSongs.map((song) {
                          final songData = song.data() as Map<String, dynamic>;
                          return _buildSongCard(context, song.id, songData);
                        }),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(
    BuildContext context,
    String songId,
    Map<String, dynamic> songData,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.music_note, color: Colors.deepPurple),
        title: Text(songData['title'] ?? 'Sans titre'),
        subtitle: Text(songData['artist'] ?? 'Artiste inconnu'),
        trailing: widget.role == 'chef'
            ? PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Supprimer'),
                    onTap: () => _deleteSong(songId),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  void _showAddSongDialog(BuildContext context) {
    String selectedRegion = 'Sud';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une chanson'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _songTitleController,
                  decoration: const InputDecoration(
                    hintText: 'Titre de la chanson',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _songArtistController,
                  decoration: const InputDecoration(
                    hintText: 'Artiste',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedRegion,
                  isExpanded: true,
                  items: ['Sud', 'Merina', 'Sud-Est'].map((region) {
                    return DropdownMenuItem(
                      value: region,
                      child: Text(region),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRegion = value!;
                    });
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
              onPressed: () async {
                if (_songTitleController.text.isEmpty ||
                    _songArtistController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez remplir tous les champs')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('songs').add({
                    'title': _songTitleController.text,
                    'artist': _songArtistController.text,
                    'region': selectedRegion,
                    'lyrics': '', // Lyrics vides au départ
                    'createdAt': DateTime.now(),
                  });

                  _songTitleController.clear();
                  _songArtistController.clear();

                  if (mounted) {
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chanson ajoutée avec succès')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSong(String songId) async {
    try {
      await FirebaseFirestore.instance.collection('songs').doc(songId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chanson supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}
