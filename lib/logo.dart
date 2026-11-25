import 'package:flutter/material.dart';

import 'theme.dart';

/// Chemin du logo officiel de la chorale (aussi utilisé sur les badges).
const cheminLogo = 'assets/images/logo_ktkfa.jpg';

/// Logo officiel K.T.K.F.A, rond, cerclé d'or.
class LogoKtkfa extends StatelessWidget {
  final double taille;
  const LogoKtkfa({super.key, this.taille = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: CouleursChorale.or,
      ),
      child: ClipOval(
        child: Image.asset(
          cheminLogo,
          fit: BoxFit.cover,
          // Décodé à la taille affichée : moins de mémoire sur téléphone.
          cacheWidth: (taille * MediaQuery.devicePixelRatioOf(context)).round(),
          semanticLabel: 'Logo K.T.K.F.A',
        ),
      ),
    );
  }
}
