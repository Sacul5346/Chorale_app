import 'package:flutter/material.dart';

import 'parametres.dart';
import 'theme.dart';

/// Réglages de la chorale (chef et responsable) : planning hebdomadaire,
/// régions des chansons, heure du rappel, barème des points d'activité.
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  ParametresChorale? _p;
  bool _modifie = false;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    ParametresChorale.charger().then((p) {
      if (mounted) setState(() => _p = p);
    });
  }

  void _maj(ParametresChorale p) => setState(() {
    _p = p;
    _modifie = true;
  });

  Future<void> _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      await _p!.enregistrer();
      if (!mounted) return;
      setState(() => _modifie = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètres enregistrés pour toute la chorale.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enregistrement impossible : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<bool> _quitter() async {
    if (!_modifie) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text('Quitter sans enregistrer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (aQuitte, _) async {
        if (aQuitte) return;
        if (await _quitter() && context.mounted) {
          // canPop ne passe à true qu'après reconstruction : on ferme
          // l'écran à l'image suivante, sinon la question reviendrait.
          setState(() => _modifie = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Paramètres de la chorale')),
        body: p == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _section(
                    Icons.calendar_month,
                    'Planning des répétitions',
                    'Utilisé par « Générer les répétitions du mois ». Les '
                        'répétitions déjà créées ne changent pas.',
                  ),
                  ...p.creneaux.asMap().entries.map(
                    (e) => _carteCreneau(p, e.key, e.value),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un créneau'),
                      onPressed: () => _editerCreneau(p, null),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    Icons.public,
                    'Régions des chansons',
                    'Filtres et choix proposés à l’ajout d’une chanson.',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...p.regions.map(
                        (r) => InputChip(
                          label: Text(r),
                          onDeleted: p.regions.length > 1
                              ? () => _maj(
                                  p.copie(regions: [...p.regions]..remove(r)),
                                )
                              : null,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter'),
                        onPressed: () => _ajouterRegion(p),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _section(
                    Icons.notifications_active,
                    'Rappel des répétitions',
                    'Notification envoyée la veille sur les téléphones.',
                  ),
                  Row(
                    children: [
                      const Text('La veille à '),
                      DropdownButton<int>(
                        value: p.heureRappel,
                        items: [
                          for (var h = 6; h <= 22; h++)
                            DropdownMenuItem(value: h, child: Text('${h}h00')),
                        ],
                        onChanged: (h) => _maj(p.copie(heureRappel: h)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _section(
                    Icons.menu_book,
                    'Verset du jour',
                    'Un verset d’encouragement notifié chaque matin.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Envoyer la notification'),
                    value: p.versetActif,
                    onChanged: (v) => _maj(p.copie(versetActif: v)),
                  ),
                  if (p.versetActif)
                    Row(
                      children: [
                        const Text('Chaque jour à '),
                        DropdownButton<int>(
                          value: p.heureVerset,
                          items: [
                            for (var h = 5; h <= 21; h++)
                              DropdownMenuItem(
                                value: h,
                                child: Text('${h}h00'),
                              ),
                          ],
                          onChanged: (h) => _maj(p.copie(heureVerset: h)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _section(
                    Icons.emoji_events,
                    'Points d’activité',
                    'Servent au classement des membres du mois.',
                  ),
                  ...libellesBareme.entries.map(
                    (e) => _ligneBareme(p, e.key, e.value),
                  ),
                ],
              ),
        bottomNavigationBar: !_modifie
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _enregistrement ? null : _enregistrer,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _section(IconData icone, String titre, String aide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: CouleursChorale.or),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  aide,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteCreneau(ParametresChorale p, int index, Creneau c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CouleursChorale.lavande,
          child: Text(
            c.nomJour.substring(0, 2),
            style: const TextStyle(
              color: CouleursChorale.aubergine,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('${c.nomJour} · ${c.heure}'),
        subtitle: Text(
          '${c.lieu.isEmpty ? 'Lieu non précisé' : c.lieu}'
          '${c.aConfirmer ? '\nÀ confirmer (décoché par défaut)' : ''}',
        ),
        isThreeLine: c.aConfirmer,
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () =>
              _maj(p.copie(creneaux: [...p.creneaux]..removeAt(index))),
        ),
        onTap: () => _editerCreneau(p, index),
      ),
    );
  }

  Future<void> _editerCreneau(ParametresChorale p, int? index) async {
    final existant = index == null ? null : p.creneaux[index];
    var jour = existant?.jour ?? DateTime.tuesday;
    var aConfirmer = existant?.aConfirmer ?? false;
    final heure = TextEditingController(text: existant?.heure ?? '18h00');
    final lieu = TextEditingController(
      text:
          existant?.lieu ??
          (p.creneaux.isNotEmpty ? p.creneaux.first.lieu : ''),
    );

    final resultat = await showDialog<Creneau>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(
            index == null ? 'Nouveau créneau' : 'Modifier le créneau',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: jour,
                  decoration: const InputDecoration(labelText: 'Jour'),
                  items: joursSemaine.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => jour = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heure,
                  decoration: const InputDecoration(
                    labelText: 'Heure (ex. 18h00)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lieu,
                  decoration: const InputDecoration(labelText: 'Lieu'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('À confirmer'),
                  subtitle: const Text(
                    'Proposé décoché lors de la génération du mois',
                  ),
                  value: aConfirmer,
                  onChanged: (v) => setDialog(() => aConfirmer = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                c,
                Creneau(
                  jour: jour,
                  heure: heure.text.trim(),
                  lieu: lieu.text.trim(),
                  aConfirmer: aConfirmer,
                ),
              ),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    heure.dispose();
    lieu.dispose();
    if (resultat == null) return;
    final liste = [...p.creneaux];
    if (index == null) {
      liste.add(resultat);
    } else {
      liste[index] = resultat;
    }
    liste.sort((a, b) => a.jour.compareTo(b.jour));
    _maj(p.copie(creneaux: liste));
  }

  Future<void> _ajouterRegion(ParametresChorale p) async {
    final controller = TextEditingController();
    final region = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouvelle région'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom (ex. Nord)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (region == null || region.isEmpty || p.regions.contains(region)) return;
    _maj(p.copie(regions: [...p.regions, region]));
  }

  Widget _ligneBareme(ParametresChorale p, String cle, String libelle) {
    final valeur = p.bareme[cle] ?? 0;
    return Row(
      children: [
        Expanded(child: Text(libelle)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: valeur > -5
              ? () => _maj(p.copie(bareme: {...p.bareme, cle: valeur - 1}))
              : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            valeur > 0 ? '+$valeur' : '$valeur',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: valeur < 10
              ? () => _maj(p.copie(bareme: {...p.bareme, cle: valeur + 1}))
              : null,
        ),
      ],
    );
  }
}
