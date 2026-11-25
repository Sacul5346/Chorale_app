import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'logo.dart';
import 'roles.dart';

/// Badges imprimables des membres : logo, photo, nom et prénoms, voix (avec
/// sa couleur), devise de la chorale et un QR code propre à chaque membre.
///
/// Format carte bancaire horizontal (85,6 × 54 mm), porté en collier (fente
/// du cordon en haut), placé à taille réelle sur des planches A4 (8 badges
/// par page) avec un contour fin pour la découpe.
/// Impression en couleur conseillée.

/// Devise de la chorale (Hébreux 2:12a), telle qu'elle figure sur le logo.
const deviseChorale = '« …, Hitory ny Anaranao amin’ny Rahalahiko aho, … »';
const referenceDevise = 'Hebreo 2:12a';

const _policeNormale = 'assets/fonts/Poppins-Regular.ttf';
const _policeGrasse = 'assets/fonts/Poppins-Bold.ttf';

/// Contenu du QR code : identifiant unique et permanent du membre.
/// Pas d'email ni de donnée personnelle : seule l'app sait à qui il renvoie.
String contenuQrMembre(String uid) => 'KTKFA:MEMBRE:$uid';

/// Libellé imprimé sous le nom.
String libelleBadge({required Object? role, required Object? voix}) {
  if (roleNormalise(role) == 'chef') return 'Chef de chorale';
  return switch (voix) {
    'soprano' => 'Soprano',
    'alto' => 'Alto',
    'tenor' => 'Ténor',
    'basse' => 'Basse',
    _ => '',
  };
}

/// Couleur de la voix (pastille du badge) : repérer les pupitres d'un coup
/// d'œil. Le chef est en or.
int couleurVoix({required Object? role, required Object? voix}) {
  if (roleNormalise(role) == 'chef') return 0xFFC9A227;
  return switch (voix) {
    'soprano' => 0xFFD6457A, // rose
    'alto' => 0xFF8E5BC9, // violet
    'tenor' => 0xFF2F7FD1, // bleu
    'basse' => 0xFF2E9E6B, // vert
    _ => 0xFF8C77A8, // aubergine clair
  };
}

/// « RAKOTO Jean Paul » -> nom « RAKOTO », prénoms « Jean Paul » (usage
/// malgache : le nom d'abord). Un seul mot : tout est dans le nom.
({String nom, String prenoms}) decouperNom(String complet) {
  final mots = complet.trim().split(RegExp(r'\s+'));
  if (mots.length < 2) return (nom: complet.trim(), prenoms: '');
  return (nom: mots.first, prenoms: mots.skip(1).join(' '));
}

class BadgeMembre {
  final String uid;
  final String nom;
  final String libelle;
  final int couleur;

  /// Photo de profil (JPEG/PNG), ou null : initiales à la place.
  final Uint8List? photo;

  const BadgeMembre({
    required this.uid,
    required this.nom,
    required this.libelle,
    this.couleur = 0xFF8C77A8,
    this.photo,
  });

  /// Depuis une fiche `users`.
  factory BadgeMembre.depuisFiche(String uid, Map<String, dynamic> fiche) {
    final nom = fiche['Nom'];
    Uint8List? photo;
    final brut = fiche['photoBase64'];
    if (brut is String && brut.isNotEmpty) {
      try {
        photo = base64Decode(brut);
      } on FormatException {
        photo = null; // photo abîmée : initiales
      }
    }
    return BadgeMembre(
      uid: uid,
      nom: nom is String && nom.trim().isNotEmpty ? nom.trim() : 'Sans nom',
      libelle: libelleBadge(role: fiche['role'], voix: fiche['voix']),
      couleur: couleurVoix(role: fiche['role'], voix: fiche['voix']),
      photo: photo,
    );
  }

  String get initiales {
    final mots = nom.split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }
}

/// Logo et polices, chargés une fois (depuis l'app, ou depuis les fichiers
/// dans les tests).
class RessourcesBadge {
  final Uint8List logo;
  final Uint8List policeNormale;
  final Uint8List policeGrasse;

  const RessourcesBadge({
    required this.logo,
    required this.policeNormale,
    required this.policeGrasse,
  });

  /// Chemins des fichiers (assets), aussi utilisés par les tests.
  static const chemins = (
    logo: cheminLogo,
    normale: _policeNormale,
    grasse: _policeGrasse,
  );

  static Future<RessourcesBadge> charger() async {
    Future<Uint8List> lire(String chemin) async =>
        (await rootBundle.load(chemin)).buffer.asUint8List();
    return RessourcesBadge(
      logo: await lire(chemins.logo),
      policeNormale: await lire(chemins.normale),
      policeGrasse: await lire(chemins.grasse),
    );
  }
}

// ---------------------------------------------------------------------------
// Génération du PDF
// ---------------------------------------------------------------------------

const _mm = PdfPageFormat.mm;
// Format carte bancaire, à l'horizontale.
const _largeur = 85.6 * _mm;
const _hauteur = 54 * _mm;
const _ecart = 6 * _mm;
const _parPage = 8; // 2 colonnes × 4 lignes sur une page A4

const _hauteurEntete = 15 * _mm;
const _hauteurPied = 7.5 * _mm;
const _diametrePhoto = 21 * _mm;

// Fente pour l'attache du cordon (badge porté en collier) : 13 × 3 mm,
// centrée en haut, au format des perforatrices à badge.
const _largeurFente = 13 * _mm;
const _hauteurFente = 3 * _mm;
const _hautFente = 2.5 * _mm;

final _aubergine = PdfColor.fromInt(0xFF3F2A56);
final _aubergineFonce = PdfColor.fromInt(0xFF2A1B3D);
final _or = PdfColor.fromInt(0xFFC9A227);
final _gris = PdfColor.fromInt(0xFF6B6478);

/// PDF des badges (une ou plusieurs planches A4).
Future<Uint8List> genererBadges(
  List<BadgeMembre> membres,
  RessourcesBadge ressources,
) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(ressources.policeNormale)),
    bold: pw.Font.ttf(ByteData.sublistView(ressources.policeGrasse)),
  );
  final doc = pw.Document(
    title: membres.length == 1
        ? 'Badge ${membres.first.nom}'
        : 'Badges K.T.K.F.A',
    author: 'K.T.K.F.A',
    theme: theme,
  );
  // Une seule image du logo pour tous les badges : le PDF reste léger.
  final logo = pw.MemoryImage(ressources.logo);

  for (var i = 0; i < membres.length; i += _parPage) {
    final page = membres.skip(i).take(_parPage).toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * _mm),
        build: (_) => pw.Wrap(
          spacing: _ecart,
          runSpacing: _ecart,
          children: [for (final m in page) _badge(m, logo)],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _badge(BadgeMembre m, pw.ImageProvider logo) {
  const rayon = pw.Radius.circular(3.5 * _mm);
  final couleur = PdfColor.fromInt(m.couleur);
  final nom = decouperNom(m.nom);

  return pw.Container(
    width: _largeur,
    height: _hauteur,
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: const pw.BorderRadius.all(rayon),
      border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
    ),
    child: pw.Stack(
      children: [
        // En-tête : logo et nom de la chorale à gauche, fente au centre.
        pw.Positioned(
          left: 0,
          top: 0,
          right: 0,
          child: pw.Container(
            height: _hauteurEntete,
            padding: const pw.EdgeInsets.only(left: 4 * _mm, top: 2 * _mm),
            alignment: pw.Alignment.topLeft,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_aubergine, _aubergineFonce],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: const pw.BorderRadius.only(
                topLeft: rayon,
                topRight: rayon,
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 7.5 * _mm,
                  height: 7.5 * _mm,
                  padding: const pw.EdgeInsets.all(0.6),
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: _or,
                  ),
                  child: pw.ClipOval(
                    child: pw.Image(logo, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(width: 1.8 * _mm),
                pw.Text(
                  'K.T.K.F.A',
                  style: pw.TextStyle(
                    color: _or,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Positioned(
          left: (_largeur - _largeurFente) / 2,
          top: _hautFente,
          child: pw.SizedBox(
            width: _largeurFente,
            height: _hauteurFente,
            child: pw.CustomPaint(painter: _fente),
          ),
        ),
        pw.Positioned(
          left: 0,
          right: 0,
          top: _hauteurEntete - 5 * _mm,
          child: pw.SizedBox(
            height: 5.2 * _mm,
            child: pw.CustomPaint(painter: _courbe),
          ),
        ),

        // Photo à gauche, à cheval sur la vague.
        pw.Positioned(
          left: 5 * _mm,
          top: _hauteurEntete - 3 * _mm,
          child: _photo(m),
        ),

        // Nom, prénoms et voix au centre.
        pw.Positioned(
          left: 5 * _mm + _diametrePhoto + 3 * _mm,
          right: 25 * _mm,
          top: _hauteurEntete + 1.5 * _mm,
          bottom: _hauteurPied + 2 * _mm,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.Text(
                  nom.nom.toUpperCase(),
                  style: pw.TextStyle(
                    color: _aubergine,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (nom.prenoms.isNotEmpty)
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: pw.Text(
                    nom.prenoms,
                    style: pw.TextStyle(color: _gris, fontSize: 8),
                  ),
                ),
              if (m.libelle.isNotEmpty) ...[
                pw.SizedBox(height: 1.4 * _mm),
                // Une seule ligne, même « CHEF DE CHORALE ».
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: _pastille(m.libelle, couleur),
                ),
              ],
            ],
          ),
        ),

        // QR code à droite.
        pw.Positioned(
          right: 4 * _mm,
          top: _hauteurEntete + 1 * _mm,
          bottom: _hauteurPied + 1.2 * _mm,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: contenuQrMembre(m.uid),
                width: 17 * _mm,
                height: 17 * _mm,
                color: _aubergine,
              ),
              pw.SizedBox(height: 0.6 * _mm),
              pw.Text(
                'Scanner pour pointer',
                style: pw.TextStyle(color: _gris, fontSize: 4.3),
              ),
            ],
          ),
        ),

        // Pied : devise, liseré à la couleur de la voix.
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: pw.Container(
            height: _hauteurPied,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _aubergine,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: rayon,
                bottomRight: rayon,
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  deviseChorale,
                  style: pw.TextStyle(color: _or, fontSize: 5.6),
                ),
                pw.SizedBox(width: 2 * _mm),
                pw.Text(
                  referenceDevise,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 4.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: _hauteurPied,
          child: pw.Container(height: 0.8 * _mm, color: couleur),
        ),
      ],
    ),
  );
}

pw.Widget _pastille(String libelle, PdfColor couleur) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 2),
  decoration: pw.BoxDecoration(
    color: couleur,
    // Arrondi = demi-hauteur de la pastille.
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
  ),
  child: pw.Text(
    libelle.toUpperCase(),
    style: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 6.5,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 1.2,
    ),
  ),
);

/// Bas de l'en-tête : une vague blanche, soulignée d'un trait or comme une
/// ligne de portée. Repère du dessin : origine en bas à gauche.
void _courbe(PdfGraphics canvas, PdfPoint taille) {
  final l = taille.x, h = taille.y;
  void vague(double decalage) => canvas
    ..moveTo(0, h * 0.55 + decalage)
    ..curveTo(
      l * 0.3,
      h * 1.05 + decalage,
      l * 0.7,
      h * 0.05 + decalage,
      l,
      h * 0.5 + decalage,
    );

  // Zone blanche sous la vague.
  vague(0);
  canvas
    ..lineTo(l, 0)
    ..lineTo(0, 0)
    ..closePath()
    ..setFillColor(PdfColors.white)
    ..fillPath();

  // Trait or juste au-dessus.
  vague(1.2);
  canvas
    ..setStrokeColor(_or)
    ..setLineWidth(0.7)
    ..strokePath();
}

/// Repère de la fente du cordon (à perforer) : oblong clair en pointillés.
void _fente(PdfGraphics canvas, PdfPoint taille) {
  final r = taille.y / 2;
  canvas
    ..drawRRect(0, 0, taille.x, taille.y, r, r)
    ..setFillColor(PdfColor.fromInt(0xFFEDE7F3))
    ..fillPath()
    ..drawRRect(0, 0, taille.x, taille.y, r, r)
    ..setStrokeColor(PdfColors.white)
    ..setLineWidth(0.5)
    ..setLineDashPattern([1.5, 1.2])
    ..strokePath()
    ..setLineDashPattern();
}

pw.Widget _photo(BadgeMembre m) {
  final photo = m.photo;
  return pw.Container(
    width: _diametrePhoto,
    height: _diametrePhoto,
    padding: const pw.EdgeInsets.all(1.6),
    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: _or),
    child: pw.Container(
      padding: const pw.EdgeInsets.all(1.2),
      decoration: const pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: PdfColors.white,
      ),
      child: pw.ClipOval(
        child: photo != null
            ? pw.Image(pw.MemoryImage(photo), fit: pw.BoxFit.cover)
            : pw.Container(
                color: PdfColor.fromInt(m.couleur),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  m.initiales,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Écran : aperçu, impression, partage
// ---------------------------------------------------------------------------

/// Aperçu des badges avec boutons Imprimer et Partager (WhatsApp, email…,
/// pratique pour envoyer le PDF à un imprimeur).
class BadgesScreen extends StatelessWidget {
  final List<BadgeMembre> membres;
  const BadgesScreen({super.key, required this.membres});

  static Future<void> ouvrir(BuildContext context, List<BadgeMembre> membres) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BadgesScreen(membres: membres)),
      );

  @override
  Widget build(BuildContext context) {
    final seul = membres.length == 1;
    final fichier = seul
        ? 'badge_${membres.first.nom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf'
        : 'badges_ktkfa.pdf';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          seul ? 'Badge de ${membres.first.nom}' : 'Badges (${membres.length})',
        ),
      ),
      body: PdfPreview(
        build: (_) async =>
            genererBadges(membres, await RessourcesBadge.charger()),
        pdfFileName: fichier,
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(),
      ),
    );
  }
}
