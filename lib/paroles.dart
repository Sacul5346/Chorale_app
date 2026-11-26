/// Découpage des paroles en strophes pour l'affichage : couplets numérotés,
/// refrain reconnu et mis en valeur.
///
/// Les paroles restent saisies en texte libre ; les strophes sont séparées
/// par une ligne vide. Une strophe est un refrain si elle commence par une
/// étiquette : « Refrain », « Fiverenany », « Fiv. », « Ref. », « Réf. »…
/// (seule sur sa ligne, ou suivie de « : » et du texte). Une étiquette
/// seule (« Fiv. ») indique qu'on reprend le refrain à cet endroit.
library;

class Strophe {
  final String texte;
  final bool refrain;

  /// Numéro du couplet (null pour un refrain).
  final int? numero;

  /// « Fiv. » seul : reprise du refrain, sans le recopier.
  bool get repriseRefrain => refrain && texte.isEmpty;

  const Strophe(this.texte, {this.refrain = false, this.numero});

  @override
  bool operator ==(Object other) =>
      other is Strophe &&
      other.texte == texte &&
      other.refrain == refrain &&
      other.numero == numero;

  @override
  int get hashCode => Object.hash(texte, refrain, numero);

  @override
  String toString() => 'Strophe(${refrain ? 'refrain' : numero}, "$texte")';
}

/// Étiquette de refrain en début de strophe, suivie éventuellement de « : »,
/// « . » ou « - » puis du texte sur la même ligne.
final _refrain = RegExp(
  r'^\s*(refrain|fiverenany|fiv|ref|réf|chorus)\b\.?\s*[:\-–.]?\s*',
  caseSensitive: false,
);

/// Numéro de couplet écrit en tête : « 1. », « 2) », « 3 - », « Couplet 2 »,
/// « Andininy 3 »…
final _numero = RegExp(
  r'^\s*(?:(?:couplet|andininy|and\.?)\s*)?(\d{1,2})\s*[.)\-–:]\s*'
  r'|^\s*(?:couplet|andininy)[ \t]*(\d{1,2})[ \t]*(?:\n|$)',
  caseSensitive: false,
);

List<Strophe> decouperParoles(String paroles) {
  final blocs = paroles
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty);

  final strophes = <Strophe>[];
  var prochainNumero = 1;
  for (final bloc in blocs) {
    final r = _refrain.firstMatch(bloc);
    // « Fiverenany » doit être un mot entier : « Fivavahana… » n'est pas
    // un refrain (le \b de l'expression le garantit).
    if (r != null) {
      strophes.add(Strophe(bloc.substring(r.end).trim(), refrain: true));
      continue;
    }
    final n = _numero.firstMatch(bloc);
    if (n != null) {
      final numero = int.parse(n.group(1) ?? n.group(2)!);
      strophes.add(Strophe(bloc.substring(n.end).trim(), numero: numero));
      prochainNumero = numero + 1;
    } else {
      strophes.add(Strophe(bloc, numero: prochainNumero++));
    }
  }
  return strophes;
}
