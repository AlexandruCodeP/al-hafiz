import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/mushaf_pack.dart';
import '../services/mushaf_repository.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_grain.dart';
import '../widgets/tap_scale.dart';

/// Catalogue des editions du Mushaf : telechargement, choix de l'edition
/// active, suppression.
class MushafStyleScreen extends StatelessWidget {
  const MushafStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<MushafRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = repo.grouped;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Style d\'affichage',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (repo.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Actualiser le catalogue',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: repo.refreshCatalogue,
            ),
        ],
      ),
      body: PaperGrainOverlay(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          children: [
            if (repo.catalogueError != null && groups.isEmpty)
              _CatalogueError(
                message: repo.catalogueError!,
                onRetry: repo.refreshCatalogue,
              ),
            if (groups.isEmpty && repo.catalogueError == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  entry.key.label,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entry.value.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _PackCard(
                    status: entry.value[index],
                    isActive:
                        repo.activePackId == entry.value[index].pack.id,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Text(
                'Une edition telechargee fonctionne entierement hors ligne. '
                'Appuyez longuement sur une edition installee pour la supprimer.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final MushafPackStatus status;
  final bool isActive;

  const _PackCard({required this.status, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pack = status.pack;

    return TapScale(
      onTap: () => _onTap(context),
      onLongPress: status.isUsable ? () => _confirmDelete(context) : null,
      child: SizedBox(
        width: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceLight : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.divider
                            : AppColors.dividerLight),
                    width: isActive ? 2 : 0.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Preview(pack: pack),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _Caption(pack: pack, status: status),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _StateBadge(status: status),
                    ),
                    if (status.isBusy)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: status.progress >= 0 ? status.progress : null,
                          minHeight: 3,
                          backgroundColor: Colors.black.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (status.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  status.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              )
            else if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Edition active',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final repo = context.read<MushafRepository>();
    final storage = context.read<StorageService>();

    if (status.isBusy) {
      // Un appui pendant le telechargement l'annule ; l'archive partielle est
      // conservee pour une reprise ulterieure.
      repo.cancel(status.pack.id);
      return;
    }

    if (status.state == MushafInstallState.updateAvailable) {
      await repo.download(status.pack.id);
      return;
    }

    if (status.isUsable) {
      await repo.setActivePack(status.pack.id);
      await storage.setMushafPackId(status.pack.id);
      return;
    }

    await repo.download(status.pack.id);
    if (repo.statusOf(status.pack.id)?.isUsable ?? false) {
      await storage.setMushafPackId(status.pack.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final repo = context.read<MushafRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Supprimer ${status.pack.name} ?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          'Le pack sera efface de l\'appareil. Vous pourrez le retelecharger '
          'plus tard.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.remove(status.pack.id);
  }
}

/// Apercu de l'edition. Une image rendue quand le catalogue en fournit une,
/// sinon un aplat calligraphique neutre.
class _Preview extends StatelessWidget {
  final MushafPack pack;

  const _Preview({required this.pack});

  @override
  Widget build(BuildContext context) {
    final url = pack.previewUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const _PreviewPlaceholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _PreviewPlaceholder(),
      );
    }
    return const _PreviewPlaceholder();
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [AppColors.gradientDarkStart, AppColors.gradientDarkEnd]
              : const [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 34,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Bandeau sombre du bas de carte : nom de l'edition et poids du pack.
class _Caption extends StatelessWidget {
  final MushafPack pack;
  final MushafPackStatus status;

  const _Caption({required this.pack, required this.status});

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (status.state) {
      MushafInstallState.downloading => status.progress >= 0
          ? '${(status.progress * 100).round()} %  ·  appuyer pour annuler'
          : 'Telechargement…',
      MushafInstallState.installing => 'Installation…',
      MushafInstallState.updateAvailable => 'Mise a jour disponible',
      _ => pack.isDownloadable
          ? pack.readableSize
          : 'Bientot disponible',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pack.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille d'etat en haut a droite de la carte.
class _StateBadge extends StatelessWidget {
  final MushafPackStatus status;

  const _StateBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color background) = switch (status.state) {
      MushafInstallState.installed => (
          Icons.check_rounded,
          AppColors.primary,
        ),
      MushafInstallState.updateAvailable => (
          Icons.refresh_rounded,
          AppColors.primary,
        ),
      MushafInstallState.failed => (
          Icons.priority_high_rounded,
          AppColors.error,
        ),
      MushafInstallState.downloading ||
      MushafInstallState.installing =>
        (Icons.close_rounded, Colors.black54),
      MushafInstallState.notInstalled => (
          Icons.download_rounded,
          Colors.black54,
        ),
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: status.state == MushafInstallState.installing
          ? const Padding(
              padding: EdgeInsets.all(9),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 19, color: Colors.white),
    );
  }
}

class _CatalogueError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogueError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Catalogue indisponible',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reessayer')),
        ],
      ),
    );
  }
}
