# Packs Mushaf

Le mode Mushaf affiche le Coran exactement comme sur la planche imprimee. Les
donnees necessaires (polices et mise en page) ne sont pas embarquees dans
l'application : elles sont telechargees a la demande, edition par edition,
depuis l'ecran **Reglages → Mushaf → Style d'affichage**.

Ce document decrit le format d'un pack, comment en construire un, et ce qu'il
faut verifier avant de le diffuser.

---

## Pourquoi des polices et pas des images

Sur une image de page, on ne peut ni colorer une lettre selon les regles de
tajwid, ni surligner un intervalle de mots pendant la recitation, ni masquer un
segment pour tester le rappel. Tout cela suppose du **texte**.

Les polices QCF (King Fahd Complex) resolvent le probleme : chaque page a sa
propre police, dans laquelle **un glyphe represente un mot entier**, dessine
pour la position exacte qu'il occupe sur cette page. La somme des chasses d'une
ligne remplit donc la largeur de la planche : la justification est deja dans la
police, il n'y a rien a etirer a la main.

La contrepartie est le poids : 604 polices par edition, soit 100 a 250 Mo.
D'ou le telechargement a la demande.

---

## Contenu d'un pack

Une archive zip, entrees a la racine :

```
meta.json          identite du pack
layout.db          SQLite : mise en page + mots
fonts/p1.ttf       une police par page
fonts/p2.ttf
...
fonts/p604.ttf
```

`meta.json` :

```json
{
  "id": "madinah-1421-v2",
  "name": "Medine (1421H)",
  "riwaya": "hafs",
  "version": 1,
  "lines_per_page": 15,
  "total_pages": 604
}
```

### Schema de `layout.db`

```sql
CREATE TABLE pages (
  page_number   INTEGER NOT NULL,
  line_number   INTEGER NOT NULL,
  line_type     TEXT    NOT NULL,   -- 'ayah' | 'surah_name' | 'basmallah'
  is_centered   INTEGER NOT NULL,   -- 0 / 1
  first_word_id INTEGER,
  last_word_id  INTEGER,
  surah_number  INTEGER,            -- renseigne pour 'surah_name'
  PRIMARY KEY (page_number, line_number)
);

CREATE TABLE words (
  word_id        INTEGER PRIMARY KEY,
  surah          INTEGER NOT NULL,
  ayah           INTEGER NOT NULL,
  position       INTEGER NOT NULL,  -- rang du mot dans le verset, 1-based
  text           TEXT,              -- Unicode uthmani (copie, accessibilite)
  glyph          TEXT NOT NULL,     -- code_v2 : le glyphe rendu par la police
  page_number    INTEGER NOT NULL,
  line_number    INTEGER NOT NULL,
  is_ayah_marker INTEGER NOT NULL   -- 1 pour le rond de fin de verset
);
```

Une ligne de `pages` = une ligne imprimee. **`is_centered` est la colonne
critique** : elle designe les lignes qui ne doivent pas etre justifiees (fin de
sourate, bandeau de titre, basmala). Sans elle, ces lignes sont etirees sur
toute la largeur et la page ne ressemble plus au livre.

---

## Construire un pack

### 1. Recuperer les sources

Tout vient de la [Quranic Universal Library](https://qul.tarteel.ai) :

- **mise en page** : `Mushaf layouts` → choisir l'edition (KFGQPC V1 1405H,
  V2 1421H, V4 1441H, Warsh…) → export SQLite ;
- **polices** : `Fonts` → la famille page par page correspondant a la mise en
  page choisie (une V2 se rend avec des polices V2, pas V1) ;
- **mots / glyphes** : selon l'export, les mots sont dans la meme base que la
  mise en page ou dans une base separee.

### 2. Assembler

```bash
python3 tool/build_mushaf_pack.py \
    --layout   ~/qul/qpc-v2-layout.db \
    --words-db ~/qul/qpc-v2-words.db   `# si les mots sont ailleurs` \
    --fonts    ~/qul/qpc-v2-ttf \
    --id madinah-1421-v2 \
    --name "Medine (1421H)" \
    --riwaya hafs \
    --version 1 \
    --base-url https://votre-hebergement/packs \
    --out build/packs
```

Le script normalise les noms de colonnes des exports QUL vers le schema
ci-dessus. Si une colonne attendue n'existe pas, il s'arrete en listant les
colonnes trouvees : completez les tables d'alias en tete du script plutot que
de laisser le script deviner.

Il affiche en fin d'execution l'entree JSON complete, taille et SHA-256
compris.

### 3. Heberger et publier

1. Deposer `build/packs/<id>.zip` sur un hebergement statique (GitHub Releases,
   R2, S3…).
2. Coller l'entree affichee dans `packs/manifest.json`.
3. Verifier que l'application pointe sur le bon catalogue :

```bash
flutter run --dart-define=MUSHAF_MANIFEST_URL=https://.../manifest.json
```

Par defaut, l'application lit `packs/manifest.json` depuis la branche `master`
du depot via `raw.githubusercontent.com`.

### 4. Mettre a jour un pack

Incrementer `version` dans `meta.json` **et** dans l'entree du manifeste. Les
appareils qui ont l'ancienne version passent en « Mise a jour disponible » et
retelechargent l'archive complete au prochain appui.

---

## Cote application

| Fichier | Role |
| --- | --- |
| `lib/models/mushaf_pack.dart` | Modeles : pack, etat d'installation, page, ligne, mot |
| `lib/services/mushaf_repository.dart` | Catalogue, telechargement reprenable, verification, extraction, suppression |
| `lib/services/mushaf_layout_service.dart` | Lecture de `layout.db`, cache LRU des pages |
| `lib/services/qcf_font_service.dart` | Enregistrement des polices page par page |
| `lib/widgets/mushaf_page_view.dart` | Rendu d'une planche |
| `lib/screens/mushaf_screen.dart` | Feuilletage, synchronisation audio |
| `lib/screens/mushaf_style_screen.dart` | Catalogue et telechargements |

Sur l'appareil :

```
<application support>/mushaf/
  manifest.json        copie du catalogue, pour l'ouverture hors ligne
  tmp/<id>.zip         telechargement en cours, reprenable
  packs/<id>/
    .installed         marqueur ecrit apres verification du SHA-256
    meta.json
    layout.db
    fonts/
```

Le dossier *application support* est choisi volontairement plutot que le cache :
iOS purge le cache sous pression disque, et l'utilisateur perdrait 200 Mo sans
comprendre pourquoi.

### Limites connues

- **Les polices ne peuvent pas etre liberees.** Flutter n'expose aucune API de
  dechargement : une famille passee a `FontLoader` reste en memoire jusqu'a la
  fermeture de l'application. `QcfFontService` ne peut donc pas evincer les
  polices d'un cache ; il limite seulement le prechargement des pages voisines
  (budget de 48 Mo). Lire les 604 pages d'affilee reste couteux en memoire.
- **iOS / iCloud** : le dossier des packs devrait porter
  `NSURLIsExcludedFromBackupKey`. Cela demande un canal de plateforme, Dart seul
  n'y a pas acces.
- **Interaction au mot** : le rendu regroupe les mots consecutifs d'un meme
  verset dans un seul `Text` pour obtenir un surlignage continu. La selection
  mot a mot (mode masquage de segment) devra rendre les mots separement.

---

## Licences

Les polices KFGQPC et les impressions du complexe du Roi Fahd sont soumises aux
conditions de leur editeur. Verifier ces conditions **avant** de reheberger une
archive sur votre propre CDN : c'est le seul vrai risque juridique de cette
fonctionnalite. Les donnees de mise en page distribuees par QUL portent leurs
propres licences, indiquees sur la fiche de chaque ressource.
