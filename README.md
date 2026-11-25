# 🎵 K.T.K.F.A

**Kristiana Tanora Kerobima Fiadanana Andranovory**

> *« Hitory ny anaranao amin'ny rahalahiko aho »*

Application mobile de la chorale K.T.K.F.A : répétitions, présences, chants et paroles, playbacks, excuses, statistiques, membres du mois, anniversaires et verset du jour.

Développée avec **Flutter** et **Firebase** (Authentication + Cloud Firestore), pensée pour un usage **sur téléphone Android** avec une **connexion internet lente** (Madagascar).

**Télécharger la dernière version (APK Android) :**
https://github.com/Sacul5346/Chorale_app/releases/latest/download/chorale.apk

---

## Sommaire

1. [Les rôles](#1-les-rôles)
2. [Fonctionnalités](#2-fonctionnalités)
3. [Guide rapide par rôle](#3-guide-rapide-par-rôle)
4. [Notifications](#4-notifications)
5. [Playbacks et Google Drive](#5-playbacks-et-google-drive)
6. [Installation et diffusion de l'APK](#6-installation-et-diffusion-de-lapk)
7. [Guide technique](#7-guide-technique)

---

## 1. Les rôles

Chaque compte a un rôle, attribué par le chef. L'écran d'accueil dépend du rôle.

| Rôle | Onglets | Peut en plus… |
|---|---|---|
| **Membre** | Répétitions · Chansons · Mes excuses | répondre aux répétitions, lire les paroles, écouter les playbacks |
| **Gestionnaire de paroles** | Répétitions · Chansons · Mes excuses | ajouter/modifier les chansons, les paroles et les playbacks |
| **Chef** | Répétitions · Chansons · Membres · Excuses | **tout** : répétitions, présences, excuses, chansons, paramètres, statistiques, membres du mois, et seul à gérer les comptes et les suppléances |
| **Suppléant** *(provisoire)* | Répétitions · Chansons · Excuses | pendant l'absence du chef, tout ce que fait le chef **sauf** gérer les comptes |

Le gestionnaire de paroles est aussi un choriste : il répond aux répétitions comme un membre.

**Suppléance.** Quand le chef s'absente, il ouvre *Membres* › ⋮ sur un membre › *Nommer suppléant* et choisit le **dernier jour** de son absence. Jusqu'à la fin de ce jour, le membre a les pouvoirs du chef (un bandeau le lui rappelle), puis redevient automatiquement un simple membre. Le chef peut changer la date ou *Arrêter la suppléance* à tout moment.

L'ancien rôle **responsable** n'existe plus : les comptes qui l'avaient sont traités comme des membres.

---

## 2. Fonctionnalités

### Répétitions
- **Prochaine répétition** mise en avant (compte à rebours, heure, lieu) avec **réponse en un geste** : *Je viens*, *En retard* ou *Absent*.
- Répétitions à venir **groupées par mois**, répétitions passées repliées en bas.
- Chaque carte affiche **la réponse du membre** (« Vous venez », « Pas encore répondu »…).
- Les **chansons à répéter** qui existent dans la liste s'ouvrent directement sur leurs paroles.
- **Génération automatique du mois** à partir du planning hebdomadaire (voir *Paramètres*).
- Annulation avec motif, ou suppression définitive (efface aussi les présences et les excuses liées).

### Présences
Deux informations distinctes pour chaque membre et chaque répétition :
- **La réponse du membre**, donnée à l'avance : *Je viens* / *En retard* / *Absent*.
- **La présence constatée** par le chef : *à l'heure*, *en retard (avec / sans excuse)*, *absent (avec / sans excuse)*.

Le membre ne peut jamais modifier la présence constatée. Le chef voit un **résumé des réponses par voix** (soprano, alto, ténor, basse).

### Badges et pointage par scan
- **Badge imprimable** pour chaque membre (onglet *Membres* › ⋮ › *Imprimer le badge*, ou 🪪 pour tous) : logo, nom complet, voix, devise et un **QR code** propre au membre. Format carte bancaire horizontal, porté en collier (fente pour le cordon en haut), 8 par page A4, à découper. Proposé aussi juste après la création d'un compte.
- **Pointage par scan** (chef, suppléant) : ouvrir la répétition › *Scanner les badges*. Chaque badge scanné marque le membre *Présent à l'heure*, ou *En retard* après l'heure de début + la tolérance (15 min par défaut, réglable dans les paramètres) — *avec excuse* s'il avait prévenu dans l'app. Son nom et sa photo s'affichent pour vérifier que c'est bien lui.
- *Terminer* propose de marquer **absents** ceux qui n'ont pas été scannés (avec excuse s'ils avaient prévenu). Tout reste modifiable à la main dans le tableau.
- Fonctionne **sans internet** : les pointages sont envoyés dès que le réseau revient.

### Excuses
Pour chaque répétition, le membre peut écrire au chef. Le chef (ou son suppléant) voit les nouveaux messages dans l'onglet *Excuses* (badge « non lu ») et y répond.

### Chansons, paroles et playbacks
- Liste par **région**, avec recherche.
- **Lecture des paroles** pour tous : texte centré, taille réglable (A− / A+), **mode scène** (fond noir).
- **Défilement automatique** : au rythme du playback, ou à vitesse réglable. Toucher le texte met en pause.
- **Playback** (fichier audio sur Google Drive) : sur téléphone, il est **téléchargé une fois** puis s'écoute **sans internet**. Il reste dans l'espace privé de l'app (invisible dans la galerie ou la musique, non partageable).

### Statistiques et membres du mois
- **Statistiques** (chef, suppléant) : taux de présence par voix et par membre, sur le mois, 3 mois ou l'année.
- **Mon activité** (tous) : points, présences et détail de chaque répétition, mois par mois.
- **Membres du mois** : à la fin du mois, le chef (ou son suppléant) ouvre le **classement** (Femmes / Hommes), vérifie, puis **publie** les gagnants — **une femme et un homme**. Tout le monde voit les gagnants et l'historique.

Points par défaut (modifiables dans les paramètres) :

| Présence constatée | Points |
|---|---|
| Présent à l'heure | +3 |
| En retard avec excuse | +2 |
| En retard sans excuse | +1 |
| Absent avec excuse | 0 |
| Absent sans excuse | −1 |
| Bonus : a répondu à l'avance dans l'app | +1 |

À égalité : plus de présences à l'heure, puis moins d'absences sans excuse. Le chef ne participe pas au classement.

### Anniversaires et verset du jour
- Chacun renseigne son **anniversaire** (jour et mois, sans l'année) dans *Mon profil*. Bandeau 🎂 le jour J et écran *Anniversaires*.
- **Verset du jour** (Louis Segond 1910) affiché en haut des répétitions et notifié chaque matin.

### Paramètres de la chorale (chef, suppléant)
Menu **⋮ › Paramètres de la chorale** — aucun changement de code nécessaire :
- **Planning hebdomadaire** : jours, heures, lieux, créneaux « à confirmer ».
- **Régions** des chansons.
- **Heure du rappel** de répétition (la veille).
- **Verset du jour** : activé ou non, heure d'envoi.
- **Barème** des points d'activité.
- **Tolérance de retard** du pointage par badge.

### Comptes
- Création des comptes par le chef (onglet *Membres*) : nom, email, mot de passe provisoire, rôle, voix, genre, anniversaire.
- **Désactivation** d'un compte (au lieu de la suppression) : la personne ne peut plus entrer, ses playbacks téléchargés et ses rappels sont effacés de son téléphone, son historique est conservé. Réactivation possible.
- *Mot de passe oublié* sur l'écran de connexion.

---

## 3. Guide rapide par rôle

**Membre**
1. Répondre à la prochaine répétition depuis la grande carte en haut de l'écran.
2. Pour une absence, ouvrir la répétition puis 💬 pour envoyer une excuse.
3. *Chansons* › toucher une chanson › ▶️ pour télécharger et écouter le playback.
4. Menu ⋮ › *Mon profil* : photo, nom, anniversaire, mot de passe.

**Chef** (et suppléant, sauf l'étape 6)
1. ✨ *Générer les répétitions du mois* (ce mois-ci ou le mois prochain).
2. ➕ *Répétition* pour une répétition exceptionnelle ; *Choisir dans la liste* pour les chansons.
3. ⋮ sur une répétition : modifier, annuler (avec motif) ou supprimer.
4. Après la répétition : l'ouvrir et marquer la présence de chacun.
5. *Excuses* : lire et répondre ; en fin de mois : 🏆 › *Classement* › *Publier*.
6. *Membres* › ➕ pour créer un compte ; ⋮ sur un membre pour modifier, nommer un suppléant ou désactiver.

**Gestionnaire de paroles**
1. *Chansons* › ✏️ sur une chanson : saisir les paroles, ajouter le lien du playback.
2. 📁 *Associer les playbacks* : relier d'un coup tout un dossier Google Drive (voir section 5).

---

## 4. Notifications

Les notifications sont **programmées sur le téléphone** (application Android uniquement) : elles fonctionnent sans serveur et arrivent même sans internet.

| Notification | Quand |
|---|---|
| Rappel de répétition | la veille, à l'heure réglée dans les paramètres (18h par défaut) |
| Répétition annulée | à la prochaine ouverture de l'app après l'annulation |
| Verset du jour | chaque matin (6h par défaut) |
| Anniversaire | le jour J à 8h |

Au premier lancement, Android demande l'autorisation d'afficher des notifications : il faut l'accepter. Les notifications se mettent à jour chaque fois que l'app est ouverte.

---

## 5. Playbacks et Google Drive

Les fichiers audio sont hébergés sur **Google Drive** (gratuit) ; l'app ne stocke que leur lien.

**Préparer le dossier (une fois)**
1. Créer un dossier Drive, par exemple *Chorale – Playbacks*, de préférence avec un compte Google de la chorale.
2. ⋮ › *Partager* › Accès général : **« Tous les utilisateurs disposant du lien »** (Lecteur).
3. Y déposer **uniquement** des fichiers audio, **nommés comme les chansons dans l'app** (`Ry Tompo.mp3`).

**Relier les playbacks aux chansons**
- *En une fois* : Gestion des chansons › 📁 › coller le lien du dossier › vérifier les correspondances › *Relier*.
  La comparaison ignore majuscules, accents, extension, ponctuation et numéro de piste (« 03 - »).
- *Une par une* : éditeur de la chanson › *Playback* › *Ajouter* › coller le lien du fichier.

**Conseils**
- Préférer des fichiers légers : un MP3 à 64-96 kbit/s (≈ 2-4 Mo pour 4 minutes) suffit pour répéter.
- Ne pas supprimer un fichier déjà relié (le lien ne marcherait plus) ; le déplacer ou le renommer ne pose pas de problème.
- ⚠️ Ne jamais mettre de fichier sensible dans un dossier partagé par lien.

---

## 6. Installation et diffusion de l'APK

### Installer sur un téléphone
1. Ouvrir le lien de téléchargement (en haut de cette page) sur le téléphone.
2. Ouvrir le fichier `chorale.apk` ; autoriser l'installation depuis cette source si Android le demande.
3. Se connecter avec l'email et le mot de passe fournis par le chef.

Les mises à jour s'installent **par-dessus** l'application existante.

### Publier une nouvelle version
1. Augmenter `version:` dans `pubspec.yaml` (ex. `1.2.0+3` → `1.3.0+4`).
2. Commiter et pousser sur `main`.
3. GitHub › onglet **Actions** › **Fabriquer l'APK** › **Run workflow**.
4. Environ 10 minutes plus tard, la Release `vX.Y.Z` est publiée et le lien de téléchargement pointe vers elle.

Le workflow ([.github/workflows/build-apk.yml](.github/workflows/build-apk.yml)) lance aussi `flutter analyze` et `flutter test` : une erreur bloque la publication.

### Secrets GitHub nécessaires
*Settings › Secrets and variables › Actions*

| Secret | Contenu |
|---|---|
| `KEYSTORE_BASE64` | clé de signature Android (`.p12`) encodée en base64 |
| `KEYSTORE_PASSWORD` | mot de passe de la clé |
| `DRIVE_API_KEY` | clé API Google limitée à *Google Drive API* (facultative, pour l'association des playbacks) |

> 🔐 **La clé de signature ne doit jamais être perdue ni publiée.** Sans elle, les téléphones refusent les mises à jour (il faudrait désinstaller puis réinstaller l'app partout). Elle est conservée **hors du dépôt**, avec deux copies de secours privées.

---

## 7. Guide technique

### Prérequis
- Flutter 3.47.5 (Dart 3.13)
- Un accès au projet Firebase `apktkfa`

### Lancer en local (Chrome)
```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=cle_drive.json
```
`cle_drive.json` (exclu de Git) contient la clé API Google Drive :
```json
{ "DRIVE_API_KEY": "AIza..." }
```
Sans ce fichier, l'app fonctionne, mais la lecture des playbacks dans le navigateur et l'association automatique sont désactivées. Dans VS Code, la configuration *Chorale (Chrome)* ([.vscode/launch.json](.vscode/launch.json)) l'utilise automatiquement.

Dans le navigateur, il n'y a pas de téléchargement de playback ni de notification : ces fonctions n'existent que dans l'application Android.

### Vérifications
```bash
flutter analyze   # doit afficher « No issues found! »
flutter test
```

### Données Firestore

| Collection | Contenu |
|---|---|
| `users/{uid}` | `Nom`, `email`, `role`, `voix`, `genre`, `actif`, `photoBase64`, `suppleantJusquau` (fin de suppléance, écrit par le chef) |
| `repetitions/{id}` | `titre`, `date` (à minuit), `heure` (texte), `lieu`, `raison`, `chansons` (une par ligne), `statut` (`actif` / `annulé`), `causeAnnulation` |
| `presences/{id}` | `userId`, `repetitionId`, `intention` + `intentionAt` (réponse du membre), `statut` + `valideePar` + `confirmedAt` (constat du chef ou du suppléant) |
| `conversations/{repId}_{membreId}` | dernier message, `unreadByResponsable` (non lu par le chef ou le suppléant ; nom historique conservé) ; sous-collection `messages` |
| `songs/{id}` | `title`, `artist`, `region`, `lyrics`, `playbackUrl` |
| `parametres/chorale` | planning, régions, heures de rappel et du verset, barème |
| `recompenses/{AAAA-MM}` | membres du mois publiés (`femmes`, `hommes`) |
| `anniversaires/{uid}` | `nom`, `jour`, `mois`, `actif` |

### Règles de sécurité
Les règles complètes sont dans [firestore.rules](firestore.rules) : rôle lu dans `users/{uid}`, comptes désactivés bloqués, membre limité à sa propre réponse et à ses propres excuses, rôle et voix non modifiables par l'intéressé.
Elles se publient dans la console Firebase (*Firestore Database › Règles*). Elles restent compatibles avec l'ancienne version 1.0.0 de l'app, qui range la réponse du membre dans `statut`.

### Organisation du code (`lib/`)

| Fichier(s) | Rôle |
|---|---|
| `main.dart` | démarrage, `AuthGate` (redirection selon le rôle, blocage des comptes désactivés) |
| `theme.dart` | identité visuelle (aubergine, or, crème) |
| `*_screen.dart` | écrans (répétitions, présences, chansons, paroles, membres, messages, statistiques, paramètres…) |
| `repetition_model.dart` | modèle de répétition, `dateSansHeure` |
| `parametres.dart` | paramètres de la chorale (valeurs par défaut incluses) |
| `statistiques.dart`, `activite.dart` | calculs des statistiques, des points et du classement |
| `playback.dart`, `telechargement_*.dart` | lecteur audio, liens Drive, téléchargement sur le téléphone |
| `association_playbacks*.dart` | association automatique d'un dossier Drive |
| `rappels.dart` | notifications locales (rappels, annulations, verset, anniversaires) |
| `anniversaires.dart`, `versets.dart` | anniversaires, liste des versets |

La logique de calcul (statistiques, points, dates, rappels, noms de fichiers) est séparée des écrans et couverte par les tests de `test/`.
