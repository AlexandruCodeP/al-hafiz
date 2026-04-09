import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_grain.dart';
import '../widgets/tap_scale.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

// ─────────────────────────────────────────────
// French names for all 114 surahs
// ─────────────────────────────────────────────
const _frenchNames = <int, String>{
  1: 'Prologue',
  2: 'La Vache',
  3: "La Famille d'Imran",
  4: 'Les Femmes',
  5: 'La Table Servie',
  6: 'Les Bestiaux',
  7: 'Les Murailles',
  8: 'Le Butin',
  9: 'Le Repentir',
  10: 'Jonas',
  11: 'Hud',
  12: 'Joseph',
  13: 'Le Tonnerre',
  14: 'Abraham',
  15: 'Al-Hijr',
  16: 'Les Abeilles',
  17: 'Le Voyage Nocturne',
  18: 'La Caverne',
  19: 'Marie',
  20: 'Ta-Ha',
  21: 'Les Prophètes',
  22: 'Le Pèlerinage',
  23: 'Les Croyants',
  24: 'La Lumière',
  25: 'Le Discernement',
  26: 'Les Poètes',
  27: 'Les Fourmis',
  28: 'Le Récit',
  29: "L'Araignée",
  30: 'Les Romains',
  31: 'Luqman',
  32: 'La Prosternation',
  33: 'Les Coalisés',
  34: 'Saba',
  35: 'Le Créateur',
  36: 'Ya-Sin',
  37: 'Les Rangés',
  38: 'Sad',
  39: 'Les Groupes',
  40: 'Le Pardonneur',
  41: 'Les Versets Détaillés',
  42: 'La Consultation',
  43: "L'Ornement",
  44: 'La Fumée',
  45: "L'Agenouillée",
  46: 'Al-Ahqaf',
  47: 'Muhammad',
  48: 'La Victoire',
  49: 'Les Appartements',
  50: 'Qaf',
  51: 'Qui Éparpillent',
  52: 'Le Mont',
  53: "L'Étoile",
  54: 'La Lune',
  55: 'Le Tout Miséricordieux',
  56: "L'Événement",
  57: 'Le Fer',
  58: 'La Discussion',
  59: "L'Exode",
  60: "L'Éprouvée",
  61: 'Le Rang',
  62: 'Le Vendredi',
  63: 'Les Hypocrites',
  64: 'La Grande Perte',
  65: 'Le Divorce',
  66: "L'Interdiction",
  67: 'La Royauté',
  68: 'La Plume',
  69: 'Celle qui Montre la Vérité',
  70: 'Les Voies d\'Ascension',
  71: 'Noé',
  72: 'Les Djinns',
  73: "L'Enveloppé",
  74: 'Le Revêtu d\'un Manteau',
  75: 'La Résurrection',
  76: "L'Homme",
  77: 'Les Envoyés',
  78: 'La Nouvelle',
  79: 'Les Anges qui Arrachent',
  80: 'Il S\'est Renfrogné',
  81: "L'Obscurcissement",
  82: 'La Rupture',
  83: 'Les Fraudeurs',
  84: 'La Déchirure',
  85: 'Les Constellations',
  86: "L'Astre Nocturne",
  87: 'Le Très-Haut',
  88: "L'Enveloppante",
  89: "L'Aube",
  90: 'La Cité',
  91: 'Le Soleil',
  92: 'La Nuit',
  93: 'Le Jour Montant',
  94: "L'Ouverture",
  95: 'Le Figuier',
  96: "L'Adhérence",
  97: 'La Destinée',
  98: 'La Preuve',
  99: 'La Secousse',
  100: 'Les Coursiers',
  101: 'Le Fracas',
  102: 'La Course aux Richesses',
  103: "Le Temps",
  104: 'Le Calomniateur',
  105: "L'Éléphant",
  106: 'Quraysh',
  107: "L'Ustensile",
  108: "L'Abondance",
  109: 'Les Mécréants',
  110: 'Le Secours',
  111: 'Les Fibres',
  112: 'Le Monothéisme Pur',
  113: "L'Aube Naissante",
  114: 'Les Hommes',
};

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen>
    with SingleTickerProviderStateMixin {
  List<Surah> _surahs = [];
  List<Surah> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final surahs = await QuranService.instance.getAllSurahs();
    setState(() {
      _surahs = surahs;
      _filtered = surahs;
      _isLoading = false;
    });
    _animController.forward();
  }

  void _filterSurahs(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _surahs);
    } else {
      // Also search by French name
      final q = query.toLowerCase();
      setState(() {
        _filtered = _surahs.where((s) {
          final french = _frenchNames[s.id]?.toLowerCase() ?? '';
          return s.name.contains(query) ||
              s.transliteration.toLowerCase().contains(q) ||
              s.id.toString() == query ||
              french.contains(q);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _openSurah(Surah surah, {int? ayahId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(surah: surah, initialAyahId: ayahId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (lastSurahId, lastAyahId) = storage.getLastPosition();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: PaperGrainOverlay(
        child: Column(
          children: [
            // ── Top section (safe area + title + search + quick access) ──
            Container(
              padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Al-Hafiz',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  _SearchBar(
                    controller: _searchController,
                    onChanged: _filterSurahs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Quick access cards
                  _QuickAccessRow(
                    lastSurahId: lastSurahId,
                    lastAyahId: lastAyahId ?? 1,
                    bookmarks: storage.getBookmarks(),
                    isDark: isDark,
                    onResumeTap: lastSurahId == null
                        ? null
                        : () async {
                            final surah = await QuranService.instance
                                .getSurah(lastSurahId);
                            if (mounted) _openSurah(surah, ayahId: lastAyahId);
                          },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            // ── Surah grid ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primary))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final surah = _filtered[index];
                        return _SurahGridCell(
                          surah: surah,
                          frenchName: _frenchNames[surah.id] ?? '',
                          isDark: isDark,
                          onTap: () => _openSurah(surah),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _SearchBar(
      {required this.controller,
      required this.onChanged,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher sourate...',
          hintStyle: GoogleFonts.poppins(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : IconButton(
                  icon: Icon(Icons.manage_search_rounded,
                      color: AppColors.primary, size: 22),
                  tooltip: 'Recherche avancee',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SearchScreen())),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Access Row
// ─────────────────────────────────────────────
class _QuickAccessRow extends StatelessWidget {
  final int? lastSurahId;
  final int lastAyahId;
  final List<String> bookmarks;
  final bool isDark;
  final VoidCallback? onResumeTap;

  const _QuickAccessRow({
    required this.lastSurahId,
    required this.lastAyahId,
    required this.bookmarks,
    required this.isDark,
    this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (lastSurahId != null)
            FutureBuilder<Surah>(
              future: QuranService.instance.getSurah(lastSurahId!),
              builder: (context, snapshot) {
                final name = snapshot.data?.transliteration ?? '...';
                return _QuickCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Reprendre',
                  subtitle: '$name v.$lastAyahId',
                  isDark: isDark,
                  isActive: true,
                  onTap: onResumeTap,
                );
              },
            ),
          if (lastSurahId != null) const SizedBox(width: 10),
          if (bookmarks.isEmpty) ...[
            _QuickCard(
              icon: Icons.bookmark_outline_rounded,
              title: 'Signet 1',
              subtitle: 'Ajouter depuis le lecteur',
              isDark: isDark,
              isActive: false,
            ),
            const SizedBox(width: 10),
            _QuickCard(
              icon: Icons.bookmark_outline_rounded,
              title: 'Signet 2',
              subtitle: 'Ajouter depuis le lecteur',
              isDark: isDark,
              isActive: false,
            ),
          ] else
            ...bookmarks.take(2).map((bk) {
              final parts = bk.split(':');
              final surahId = int.tryParse(parts[0]) ?? 1;
              final ayahId =
                  int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FutureBuilder<Surah>(
                  future: QuranService.instance.getSurah(surahId),
                  builder: (context, snapshot) {
                    final name = snapshot.data?.transliteration ?? '...';
                    return _QuickCard(
                      icon: Icons.bookmark_rounded,
                      title: name,
                      subtitle: 'v. $ayahId',
                      isDark: isDark,
                      isActive: true,
                      onTap: () async {
                        final surah =
                            await QuranService.instance.getSurah(surahId);
                        if (context.mounted) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReaderScreen(
                                    surah: surah, initialAyahId: ayahId),
                              ));
                        }
                      },
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final bool isActive;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.divider : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: isActive
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? (isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight)
                          : (isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Surah Grid Cell — compact 4-column card
// ─────────────────────────────────────────────
class _SurahGridCell extends StatelessWidget {
  final Surah surah;
  final String frenchName;
  final bool isDark;
  final VoidCallback onTap;

  const _SurahGridCell({
    required this.surah,
    required this.frenchName,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scaleDown: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppColors.divider.withValues(alpha: 0.3)
                : AppColors.dividerLight.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Arabic name (calligraphic) ──
            Text(
              surah.name,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 20,
                height: 1.3,
                color: isDark ? AppColors.accent : const Color(0xFF8B6914),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // ── Number + transliteration ──
            Text(
              '${surah.id}. ${surah.transliteration.toUpperCase()}',
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // ── French name ──
            Text(
              frenchName.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF6B5D4D),
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // ── Verse count ──
            Text(
              '${surah.totalVerses} versets',
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: isDark
                    ? AppColors.textSecondary.withValues(alpha: 0.7)
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
