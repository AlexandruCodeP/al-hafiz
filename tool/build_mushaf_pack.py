#!/usr/bin/env python3
"""Assemble un pack Mushaf telechargeable pour Al-Hafiz.

Entrees attendues (a recuperer sur https://qul.tarteel.ai) :

  * une base SQLite de *mushaf layout* : la table `pages` y decrit une ligne
    imprimee par enregistrement (page, ligne, type, centrage, bornes de mots) ;
  * une source de *mots* : soit la meme base si elle contient une table de
    mots, soit une seconde base (`--words-db`) issue d'un script glyphe ;
  * un dossier de polices page par page : `p1.ttf` ... `p604.ttf`.

Sortie : `<id>.zip` contenant `meta.json`, `layout.db` et `fonts/`, plus
l'entree JSON a coller dans `packs/manifest.json` (taille et SHA-256 inclus).

Exemple :

    python3 tool/build_mushaf_pack.py \\
        --layout ~/qul/qpc-v2-layout.db \\
        --fonts  ~/qul/qpc-v2-ttf \\
        --id madinah-1421-v2 --name "Medine (1421H)" \\
        --riwaya hafs --version 1 \\
        --out build/packs

Le script n'invente rien : si une colonne attendue est absente, il s'arrete en
listant les colonnes reellement trouvees, pour que le mapping soit corrige a la
main plutot que devine.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import zipfile
from datetime import datetime, timezone

# Noms de colonnes rencontres dans les exports QUL, par champ de notre schema.
PAGE_ALIASES = {
    "page_number": ("page_number", "page", "page_id"),
    "line_number": ("line_number", "line", "line_no"),
    "line_type": ("line_type", "type"),
    "is_centered": ("is_centered", "centered"),
    "first_word_id": ("first_word_id", "first_word", "from_word_id"),
    "last_word_id": ("last_word_id", "last_word", "to_word_id"),
    "surah_number": ("surah_number", "surah", "chapter_id", "chapter_number"),
}

WORD_ALIASES = {
    "word_id": ("word_id", "id", "word_index"),
    "surah": ("surah", "surah_number", "chapter_id", "chapter_number"),
    "ayah": ("ayah", "ayah_number", "verse_number", "verse_id"),
    "position": ("position", "word_position", "word_number"),
    "text": ("text", "text_uthmani", "qpc_uthmani_hafs", "word_text"),
    "glyph": ("glyph", "code_v2", "code_v1", "code", "qpc_v2", "text_qpc"),
    "page_number": ("page_number", "page", "page_id"),
    "line_number": ("line_number", "line", "line_no"),
    "char_type": ("char_type", "char_type_name", "is_ayah_marker"),
}

TARGET_SCHEMA = """
CREATE TABLE pages (
  page_number   INTEGER NOT NULL,
  line_number   INTEGER NOT NULL,
  line_type     TEXT    NOT NULL,
  is_centered   INTEGER NOT NULL DEFAULT 0,
  first_word_id INTEGER,
  last_word_id  INTEGER,
  surah_number  INTEGER,
  PRIMARY KEY (page_number, line_number)
);

CREATE TABLE words (
  word_id        INTEGER PRIMARY KEY,
  surah          INTEGER NOT NULL,
  ayah           INTEGER NOT NULL,
  position       INTEGER NOT NULL DEFAULT 0,
  text           TEXT,
  glyph          TEXT NOT NULL,
  page_number    INTEGER NOT NULL,
  line_number    INTEGER NOT NULL,
  is_ayah_marker INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_words_page ON words(page_number, line_number, word_id);
CREATE INDEX idx_words_ayah ON words(surah, ayah, position);
"""


class BuildError(Exception):
    pass


def columns_of(conn: sqlite3.Connection, table: str) -> list[str]:
    rows = conn.execute(f'PRAGMA table_info("{table}")').fetchall()
    if not rows:
        raise BuildError(f"table « {table} » introuvable")
    return [r[1] for r in rows]


def find_table(conn: sqlite3.Connection, candidates: tuple[str, ...]) -> str:
    names = {
        r[0]
        for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    }
    for candidate in candidates:
        if candidate in names:
            return candidate
    raise BuildError(
        f"aucune table parmi {candidates} ; tables presentes : {sorted(names)}"
    )


def resolve(available: list[str], aliases: dict[str, tuple[str, ...]],
            required: set[str], table: str) -> dict[str, str | None]:
    lowered = {c.lower(): c for c in available}
    mapping: dict[str, str | None] = {}
    for field, options in aliases.items():
        mapping[field] = next(
            (lowered[o] for o in options if o in lowered), None
        )
    missing = [f for f in required if mapping.get(f) is None]
    if missing:
        raise BuildError(
            f"colonnes manquantes dans « {table} » : {missing}\n"
            f"colonnes disponibles : {available}\n"
            "Completez les alias en tete de ce script."
        )
    return mapping


def normalise_line_type(raw: object) -> str:
    value = (str(raw) if raw is not None else "").strip().lower()
    if value in ("surah_name", "surah", "chapter", "surah_header"):
        return "surah_name"
    if value in ("basmallah", "bismillah", "basmala"):
        return "basmallah"
    return "ayah"


def is_marker(char_type: object) -> int:
    value = (str(char_type) if char_type is not None else "").strip().lower()
    return 1 if value in ("end", "1", "true", "ayah_marker") else 0


def build_layout(layout_db: str, words_db: str | None, dest: str) -> tuple[int, int]:
    """Reecrit les donnees source dans notre schema. Renvoie (lignes, mots)."""
    if os.path.exists(dest):
        os.remove(dest)

    src = sqlite3.connect(f"file:{layout_db}?mode=ro", uri=True)
    words_src = (
        sqlite3.connect(f"file:{words_db}?mode=ro", uri=True) if words_db else src
    )
    out = sqlite3.connect(dest)
    try:
        out.executescript(TARGET_SCHEMA)

        pages_table = find_table(src, ("pages", "mushaf_pages", "layout"))
        page_map = resolve(
            columns_of(src, pages_table),
            PAGE_ALIASES,
            {"page_number", "line_number"},
            pages_table,
        )

        select_cols = ", ".join(
            f'"{col}"' for col in page_map.values() if col is not None
        )
        order = [f for f, c in page_map.items() if c is not None]
        rows = src.execute(
            f'SELECT {select_cols} FROM "{pages_table}"'
        ).fetchall()

        page_rows = []
        for row in rows:
            record = dict(zip(order, row))
            page_rows.append(
                (
                    int(record["page_number"]),
                    int(record["line_number"]),
                    normalise_line_type(record.get("line_type")),
                    1 if record.get("is_centered") in (1, "1", True, "true") else 0,
                    record.get("first_word_id"),
                    record.get("last_word_id"),
                    record.get("surah_number"),
                )
            )
        out.executemany(
            "INSERT OR REPLACE INTO pages VALUES (?,?,?,?,?,?,?)", page_rows
        )

        words_table = find_table(words_src, ("words", "glyphs", "word_glyphs"))
        word_map = resolve(
            columns_of(words_src, words_table),
            WORD_ALIASES,
            {"word_id", "surah", "ayah", "glyph", "page_number", "line_number"},
            words_table,
        )
        select_cols = ", ".join(
            f'"{col}"' for col in word_map.values() if col is not None
        )
        order = [f for f, c in word_map.items() if c is not None]

        word_rows = []
        for row in words_src.execute(
            f'SELECT {select_cols} FROM "{words_table}"'
        ):
            record = dict(zip(order, row))
            glyph = record.get("glyph")
            if glyph is None:
                continue
            word_rows.append(
                (
                    int(record["word_id"]),
                    int(record["surah"]),
                    int(record["ayah"]),
                    int(record.get("position") or 0),
                    record.get("text"),
                    str(glyph),
                    int(record["page_number"]),
                    int(record["line_number"]),
                    is_marker(record.get("char_type")),
                )
            )
        out.executemany(
            "INSERT OR REPLACE INTO words VALUES (?,?,?,?,?,?,?,?,?)", word_rows
        )
        out.commit()
        out.execute("VACUUM")
        return len(page_rows), len(word_rows)
    finally:
        out.close()
        src.close()
        if words_src is not src:
            words_src.close()


def collect_fonts(fonts_dir: str, total_pages: int) -> list[tuple[str, str]]:
    found = []
    missing = []
    for page in range(1, total_pages + 1):
        for name in (f"p{page}.ttf", f"QCF_P{page:03d}.ttf", f"p{page:03d}.ttf"):
            path = os.path.join(fonts_dir, name)
            if os.path.exists(path):
                # Le lecteur cherche toujours `fonts/p<N>.ttf`.
                found.append((path, f"fonts/p{page}.ttf"))
                break
        else:
            missing.append(page)
    if missing:
        raise BuildError(
            f"{len(missing)} police(s) manquante(s), a partir de la page "
            f"{missing[0]} — verifiez --fonts"
        )
    return found


def sha256_of(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", required=True, help="SQLite de mushaf layout")
    parser.add_argument("--words-db", help="SQLite des mots, si separee")
    parser.add_argument("--fonts", required=True, help="dossier des polices")
    parser.add_argument("--id", required=True, help="identifiant du pack")
    parser.add_argument("--name", required=True, help="nom affiche")
    parser.add_argument("--riwaya", default="hafs",
                        choices=["hafs", "warsh", "qalun", "other"])
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--lines-per-page", type=int, default=15)
    parser.add_argument("--total-pages", type=int, default=604)
    parser.add_argument("--base-url", default="",
                        help="prefixe d'URL d'hebergement, pour le manifeste")
    parser.add_argument("--out", default="build/packs")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    staging = tempfile.mkdtemp(prefix=f"{args.id}-")
    try:
        layout_path = os.path.join(staging, "layout.db")
        lines, words = build_layout(args.layout, args.words_db, layout_path)
        print(f"layout.db : {lines} lignes, {words} mots")

        fonts = collect_fonts(args.fonts, args.total_pages)
        print(f"polices   : {len(fonts)} fichiers")

        meta = {
            "id": args.id,
            "name": args.name,
            "riwaya": args.riwaya,
            "version": args.version,
            "lines_per_page": args.lines_per_page,
            "total_pages": args.total_pages,
            "built_at": datetime.now(timezone.utc).isoformat(),
        }
        meta_path = os.path.join(staging, "meta.json")
        with open(meta_path, "w", encoding="utf-8") as handle:
            json.dump(meta, handle, ensure_ascii=False, indent=2)

        archive = os.path.join(args.out, f"{args.id}.zip")
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(meta_path, "meta.json")
            zf.write(layout_path, "layout.db")
            for source, arcname in fonts:
                zf.write(source, arcname)

        size = os.path.getsize(archive)
        entry = {
            "id": args.id,
            "name": args.name,
            "riwaya": args.riwaya,
            "version": args.version,
            "lines_per_page": args.lines_per_page,
            "total_pages": args.total_pages,
            "bytes": size,
            "sha256": sha256_of(archive),
            "url": f"{args.base_url.rstrip('/')}/{args.id}.zip"
            if args.base_url
            else "",
        }
        print(f"\narchive   : {archive} ({size / (1024 * 1024):.1f} Mo)")
        print("\nEntree a ajouter dans packs/manifest.json :\n")
        print(json.dumps(entry, ensure_ascii=False, indent=2))
        return 0
    except BuildError as error:
        print(f"erreur : {error}", file=sys.stderr)
        return 1
    finally:
        shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
