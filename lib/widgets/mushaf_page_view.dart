import 'package:flutter/material.dart';

import '../models/mushaf_pack.dart';
import '../services/qcf_font_service.dart';
import '../theme/app_theme.dart';

/// Rend une planche du Mushaf ligne par ligne, a l'identique du livre imprime.
///
/// Deux details font toute la difference avec un rendu approximatif :
///
/// 1. les glyphes des polices QCF sont dessines **page par page**, deja
///    justifies : la somme des chasses d'une ligne remplit exactement la
///    largeur de la planche. Il n'y a donc rien a etirer a la main — un
///    [FittedBox] par ligne suffit, et l'echelle obtenue est la meme partout ;
/// 2. la colonne `is_centered` de `layout.db` designe les lignes qui ne
///    doivent **pas** etre justifiees (fin de sourate, bandeau, basmala). Sans
///    elle, ces lignes sont etirees sur toute la largeur et la page « sonne
///    faux ».
class MushafPageView extends StatelessWidget {
  final MushafPage page;

  /// Identifiant du pack, pour resoudre la famille de police de la page.
  final String packId;

  /// Vrai quand la police de cette page est enregistree. Sinon on retombe sur
  /// le texte Unicode, lisible mais sans la mise en page d'origine.
  final bool fontReady;

  /// Verset a surligner (recitation en cours ou selection).
  final int? highlightedSurah;
  final int? highlightedAyah;

  /// Noms arabes des sourates, pour les bandeaux de titre.
  final Map<int, String> surahNames;

  final void Function(int surah, int ayah)? onAyahTap;

  const MushafPageView({
    super.key,
    required this.page,
    required this.packId,
    required this.surahNames,
    this.fontReady = false,
    this.highlightedSurah,
    this.highlightedAyah,
    this.onAyahTap,
  });

  static const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  String get _family =>
      QcfFontService.instance.familyFor(packId, page.pageNumber);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textArabic : AppColors.textPrimaryLight;

    // Proportions d'une planche imprimee : sans elles, sur un ecran large les
    // lignes justifiees seraient etirees au-dela de leur hauteur de ligne.
    return Center(
      child: AspectRatio(
        aspectRatio: 0.66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in page.lines)
                Expanded(child: _buildLine(context, line, ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, MushafLine line, Color ink) {
    switch (line.type) {
      case MushafLineType.surahName:
        return _SurahBanner(
          name: surahNames[line.surahNumber] ?? '',
          ink: ink,
        );
      case MushafLineType.basmallah:
        return _centered(_buildText(line, ink));
      case MushafLineType.ayah:
        if (line.words.isEmpty) return const SizedBox.shrink();
        return line.isCentered
            ? _centered(_buildText(line, ink))
            : FittedBox(
                fit: BoxFit.fitWidth,
                child: _buildText(line, ink),
              );
    }
  }

  Widget _centered(Widget child) => Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      );

  /// Assemble la ligne en segments : les mots consecutifs d'un meme verset sont
  /// reunis dans un seul [Text], ce qui donne un surlignage continu au lieu
  /// d'une suite de pastilles separees.
  Widget _buildText(MushafLine line, Color ink) {
    if (line.words.isEmpty && line.type == MushafLineType.basmallah) {
      return Text(
        _basmala,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'Scheherazade', fontSize: 26, color: ink),
      );
    }

    final segments = <_AyahSegment>[];
    for (final word in line.words) {
      final piece = fontReady ? word.glyph : word.text;
      if (piece.isEmpty) continue;
      if (segments.isNotEmpty &&
          segments.last.surah == word.surah &&
          segments.last.ayah == word.ayah) {
        segments.last.buffer.write(fontReady ? piece : ' $piece');
      } else {
        segments.add(
          _AyahSegment(surah: word.surah, ayah: word.ayah)
            ..buffer.write(piece),
        );
      }
    }

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          _SegmentText(
            segment: segment,
            family: fontReady ? _family : 'Scheherazade',
            ink: ink,
            highlighted: highlightedSurah == segment.surah &&
                highlightedAyah == segment.ayah,
            onTap: onAyahTap,
          ),
      ],
    );
  }
}

class _AyahSegment {
  final int surah;
  final int ayah;
  final StringBuffer buffer = StringBuffer();

  _AyahSegment({required this.surah, required this.ayah});
}

class _SegmentText extends StatelessWidget {
  final _AyahSegment segment;
  final String family;
  final Color ink;
  final bool highlighted;
  final void Function(int surah, int ayah)? onTap;

  const _SegmentText({
    required this.segment,
    required this.family,
    required this.ink,
    required this.highlighted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      segment.buffer.toString(),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: family,
        fontSize: 30,
        color: ink,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(segment.surah, segment.ayah),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: text,
      ),
    );
  }
}

/// Bandeau de titre de sourate, dans l'esprit des cartouches imprimes.
class _SurahBanner extends StatelessWidget {
  final String name;
  final Color ink;

  const _SurahBanner({required this.name, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize: 22,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
