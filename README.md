# Al-Hafiz

**Une application de mémorisation du Coran, libre, gratuite et sans distraction.**

Al-Hafiz (الحافظ) est une application Flutter conçue autour d'un seul objectif : aider à
mémoriser le Coran. Pas de publicité, pas de compte, pas de tracking — le texte, la récitation,
et un moteur de répétition qui fait le travail à votre place.

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Captures et parcours utilisateur](#captures-et-parcours-utilisateur)
- [Démarrage rapide](#démarrage-rapide)
- [Architecture du projet](#architecture-du-projet)
- [Le moteur Hifz](#le-moteur-hifz)
- [Données et sources externes](#données-et-sources-externes)
- [Stockage local et sauvegardes](#stockage-local-et-sauvegardes)
- [Personnalisation](#personnalisation)
- [Qualité du code](#qualité-du-code)
- [Limitations connues](#limitations-connues)
- [Contribuer](#contribuer)
- [Licence et remerciements](#licence-et-remerciements)

---

## Fonctionnalités

### Lecture

- **Les 114 sourates** en arabe, embarquées dans l'application (aucune connexion nécessaire
  pour lire le texte).
- **Traduction française** et **translittération phonétique**, récupérées à la demande depuis
  l'API Quran.com et mises en cache en mémoire.
- **Tafsir (exégèse)** verset par verset, en français, avec repli automatique sur le tafsir
  arabe si la version française n'est pas disponible.
- Affichage **entièrement configurable** : arabe, traduction et phonétique s'activent
  indépendamment, chacun avec sa propre taille de texte.
- **Thème clair / sombre / système**, palette chaude inspirée du papier et de l'encre dorée.
- **Numéros de page du Mushaf** (édition Médine) associés à chaque verset.

### Écoute

- **Plus de 45 récitateurs** : Alafasy, AbdulBasit (Mujawwad et Murattal), Al-Husary,
  As-Sudais, Al-Minshawi, Al-Ghamadi, Ash-Shuraym, Maher Al-Muaiqly…
- Lecture **verset par verset** ou en **continu sur toute la sourate**, avec barre de lecture
  persistante (position, seek, boucle, répétition A-B).
- **Lecture d'un segment de mots** : sélectionnez quelques mots dans un verset au doigt, et
  seuls ces mots sont joués en boucle. Les bornes temporelles proviennent des *timestamps*
  mot-à-mot réels de l'API Quran.com quand le récitateur en dispose, avec une estimation
  proportionnelle en repli.
- Deux sources audio prises en charge : `everyayah.com` (audio par verset) et
  `mp3quran.net` (audio par sourate).

### Mémorisation

- **Mode Hifz** : choisissez une plage de versets, un nombre de répétitions par verset, un
  nombre de boucles sur la plage et une durée de pause — l'application enchaîne toute seule.
- **Mode focus** : tous les versets sauf celui en cours de lecture sont floutés.
- **Mode masquage de segment** : les mots sélectionnés sont cachés pour tester le rappel.
- **Versets maîtrisés** : marquez ce qui est acquis, la progression par sourate se calcule
  automatiquement.
- **Favoris, signets et notes personnelles** attachés à un verset précis.
- **Écran « Mes Révisions »** regroupant tout ce que vous avez marqué.
- **Reprise de lecture** : l'application rouvre à la dernière position et garde l'historique
  des sourates récentes.

### Recherche

- Recherche rapide de sourate par nom arabe, translittération, nom français ou numéro.
- **Recherche plein texte** dans les versets : texte arabe, traduction française ou phonétique.

---

## Captures et parcours utilisateur

Au premier lancement, un **onboarding en 5 écrans** présente le principe : lire, écouter et
répéter, le mode Hifz, le tafsir et la recherche, puis le suivi de progression. Ensuite,
la navigation tient en trois onglets dans une barre flottante :

| Onglet | Contenu |
| --- | --- |
| **Quran** | Liste/grille des 114 sourates, reprise de lecture, recherche |
| **Révisions** | Favoris, signets, notes et versets maîtrisés |
| **Réglages** | Thème, tailles de texte, récitateur, sauvegarde/restauration |

---

## Démarrage rapide

### Prérequis

- **Flutter** avec un SDK Dart `^3.9.2` (Flutter 3.35 ou ultérieur).
- Android Studio / Xcode selon la plateforme visée, ou simplement un navigateur pour le web.

```bash
flutter --version   # vérifiez que le SDK Dart est >= 3.9.2
```

### Installation

```bash
git clone https://github.com/AlexandruCodeP/al-hafiz.git
cd al-hafiz
flutter pub get
```

### Lancer l'application

```bash
flutter devices          # lister les cibles disponibles
flutter run              # sur la cible par défaut
flutter run -d chrome    # dans le navigateur
```

### Construire un binaire

```bash
flutter build apk --release      # Android
flutter build ipa --release      # iOS (macOS + Xcode requis)
flutter build web --release      # Web (sortie dans build/web)
```

Plateformes configurées dans le dépôt : **Android**, **iOS** et **Web**.

---

## Architecture du projet

L'application suit un découpage classique *models / services / screens / widgets*, avec
[`provider`](https://pub.dev/packages/provider) pour la diffusion d'état.

```
lib/
├── main.dart                     # Bootstrap, MultiProvider, shell de navigation
├── models/
│   ├── surah.dart                # Surah + Ayah (texte, traduction, phonétique, page)
│   ├── reciter.dart              # Catalogue des récitateurs et de leurs sources audio
│   └── juz_data.dart             # Bornes des 30 juz du Mushaf de Médine
├── services/
│   ├── quran_service.dart        # Chargement du texte, traductions, tafsir, recherche
│   ├── audio_service.dart        # Lecture just_audio, segments de mots, timestamps
│   ├── hifz_engine.dart          # Machine à états de la session de mémorisation
│   └── storage_service.dart      # Persistance SharedPreferences, export/import JSON
├── screens/
│   ├── onboarding_screen.dart
│   ├── surah_list_screen.dart
│   ├── reader_screen.dart        # Écran principal de lecture/écoute/mémorisation
│   ├── search_screen.dart
│   ├── favorites_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── ayah_card.dart            # Rendu d'un verset
│   ├── audio_player_bar.dart     # Barre de lecture persistante
│   ├── hifz_controls.dart        # Réglages de session (répétitions, pauses, plage)
│   ├── word_segment_selector.dart# Sélection de mots par glissement
│   ├── focus_mode.dart           # Floutage des versets non actifs
│   ├── note_dialog.dart
│   ├── tap_scale.dart
│   └── paper_grain.dart          # Texture de fond
├── theme/
│   └── app_theme.dart            # Palettes claire/sombre et typographie
assets/
├── quran.json                    # Texte coranique complet (114 sourates)
└── page_map.json                 # sourate → numéro de page par verset
```

### Gestion d'état

Trois fournisseurs sont installés à la racine dans `main.dart` :

| Fournisseur | Rôle |
| --- | --- |
| `AudioService` | État du lecteur, récitateur courant, segments |
| `HifzEngine` | Session de mémorisation (dépend d'`AudioService`) |
| `StorageService` | Préférences et données utilisateur |

`QuranService` est un singleton sans état d'interface : il charge les assets une seule fois et
met en cache traductions et phonétiques par sourate.

---

## Le moteur Hifz

`HifzEngine` est une petite machine à états pilotée par la fin de lecture de chaque verset :

```
idle ──startSession()──► playingAyah
                            │
              fin du verset │
                            ▼
        ┌──── répétitions restantes ? ──► pauseBetweenReps ──┐
        │                                                    │
        ├──── verset suivant dans la plage ? ─► pauseBetweenAyahs ─┤──► playingAyah
        │                                                    │
        ├──── boucle de plage restante ? ───► pauseBetweenAyahs ───┘
        │
        └──── sinon ──────────────────────► completed
```

Paramètres exposés et leurs bornes :

| Paramètre | Valeurs | Défaut |
| --- | --- | --- |
| Plage de versets | début → fin | verset courant |
| Répétitions par verset | 1 – 20 | 3 |
| Boucles sur la plage | 1 – 10 | 1 |
| Pause entre répétitions | 0 – 10 s | 2 s |

Une pause de `0` seconde enchaîne immédiatement, sans passer par un timer.

---

## Données et sources externes

Le texte arabe est **embarqué** ; tout le reste est facultatif et récupéré en ligne.

| Donnée | Source | Hors ligne ? |
| --- | --- | --- |
| Texte arabe des 114 sourates | `assets/quran.json` | ✅ |
| Numéros de page du Mushaf | `assets/page_map.json` | ✅ |
| Traduction française | API Quran.com (traduction `136`) | ❌ |
| Translittération phonétique | API Quran.com (traduction `57`) | ❌ |
| Tafsir | API Quran.com (`816` fr, repli `169` ar) | ❌ |
| Audio par verset | `everyayah.com` | ❌ |
| Audio par sourate | `mp3quran.net` | ❌ |
| Timestamps mot-à-mot | API Quran.com (`/recitations/{id}/…`) | ❌ |

Les appels réseau échouent silencieusement : sans connexion, la lecture du texte arabe reste
pleinement fonctionnelle, seuls la traduction, le tafsir et l'audio sont indisponibles.

---

## Stockage local et sauvegardes

Toutes les données utilisateur vivent **sur l'appareil**, dans `SharedPreferences` — rien n'est
envoyé à un serveur. Sont conservés : favoris, signets, notes, versets maîtrisés, dernière
position de lecture, sourates récentes, récitateur choisi, thème, tailles de texte et
préférences d'affichage.

Depuis **Réglages → Sauvegarde et restauration**, l'ensemble s'exporte en un fichier JSON
versionné (`file_picker` + `path_provider`) et se réimporte sur un autre appareil :

```json
{
  "version": 1,
  "exportedAt": "2026-01-01T12:00:00.000",
  "favorites": [...],
  "mastered": ["2:255", "..."],
  "notes": { "2:255": "..." },
  "bookmarks": [...],
  "lastSurah": 2,
  "lastAyah": 255,
  "recentSurahs": [2, 18, 36],
  "settings": { "themeMode": "dark", "reciterId": "alafasy", "...": "..." }
}
```

Un bouton **Réinitialiser toutes les données** efface l'intégralité du stockage local.

---

## Personnalisation

### Ajouter un récitateur

Les récitateurs sont déclarés dans `lib/models/reciter.dart`. Pour une source par verset
(`everyayah.com`), il suffit du nom du dossier :

```dart
Reciter(
  id: 'mon_recitateur',
  name: 'Nom Du Récitateur',
  folder: 'Nom_Du_Dossier_128kbps',
  style: 'Murattal',              // facultatif
  quranComRecitationId: 7,        // facultatif : active les timestamps mot-à-mot
),
```

Pour une source par sourate (`mp3quran.net`), précisez la source et l'URL de base :

```dart
Reciter(
  id: 'mon_recitateur',
  name: 'Nom Du Récitateur',
  folder: 'chemin/Rewayat-Hafs-A-n-Assem',
  source: ReciterSource.mp3quran,
  baseUrl: 'https://server10.mp3quran.net',
),
```

### Modifier le thème

Les couleurs sont centralisées dans `AppColors` (`lib/theme/app_theme.dart`) : une palette
sombre, une palette claire, et les dégradés d'en-tête. Les typographies latines passent par
`google_fonts` (Poppins).

---

## Qualité du code

```bash
flutter analyze     # analyse statique (règles flutter_lints 5)
flutter test        # suite de tests
```

Les règles de lint sont configurées dans `analysis_options.yaml`.

---

## Limitations connues

Autant l'écrire honnêtement, ce sont les chantiers ouverts :

- **La suite de tests est un simple *smoke test***. `test/widget_test.dart` ne monte pas encore
  l'application (elle exige une initialisation de `SharedPreferences`).
- **La police arabe `Scheherazade` est référencée mais non embarquée** dans `pubspec.yaml` : le
  rendu retombe donc sur la police arabe du système. L'ajouter dans `assets/fonts/` et la
  déclarer dans `pubspec.yaml` améliorerait nettement la typographie.
- **`JuzData` (bornes des 30 juz) est défini mais pas encore utilisé** dans l'interface — la
  navigation par juz reste à brancher.
- **Pas de cache disque** : traductions, tafsir et audio sont mis en cache en mémoire
  uniquement et redemandés au redémarrage de l'application.
- **Interface en français uniquement**, sans système d'internationalisation.

---

## Contribuer

Les contributions sont bienvenues.

1. Forkez le dépôt et créez une branche depuis `master`.
2. Vérifiez que `flutter analyze` et `flutter test` passent avant de proposer vos changements.
3. Ouvrez une Pull Request en décrivant le comportement avant/après.

Les messages de commit du projet suivent la convention `type: description` en français
(`feat:`, `fix:`, `refactor:`, `remove:`).

---

## Licence et remerciements

Ce projet se veut **libre et open source**, mais aucun fichier `LICENSE` n'a encore été ajouté
au dépôt : tant que ce n'est pas fait, les droits par défaut du droit d'auteur s'appliquent.
Ajouter une licence (MIT, Apache-2.0, GPL-3.0…) est la prochaine étape recommandée.

Merci aux projets et services sans lesquels Al-Hafiz n'existerait pas :

- [Quran.com API](https://api-docs.quran.com/) — traductions, tafsir et timestamps mot-à-mot
- [EveryAyah.com](https://everyayah.com/) — récitations verset par verset
- [MP3Quran.net](https://mp3quran.net/) — récitations par sourate
- [Flutter](https://flutter.dev/) et les paquets `just_audio`, `provider`,
  `shared_preferences`, `google_fonts`, `file_picker`, `path_provider`, `http`

> رَبِّ زِدْنِي عِلْمًا
