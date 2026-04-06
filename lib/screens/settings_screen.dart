import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reglages',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Apparence section
          Text(
            'Apparence',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: isDark ? AppColors.surfaceLight : AppColors.surfaceLightT,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.divider : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Theme',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    ),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 18)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                    ],
                    selected: {storage.themeMode},
                    onSelectionChanged: (v) => storage.setThemeMode(v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sauvegarde section
          Text(
            'Sauvegarde et restauration',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: isDark ? AppColors.surfaceLight : AppColors.surfaceLightT,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.divider : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_rounded, color: AppColors.primary),
                  title: Text(
                    'Exporter mes donnees',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Sauvegarder dans un fichier',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => _exportData(context, storage),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark ? AppColors.divider : AppColors.dividerLight,
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                  title: Text(
                    'Importer mes donnees',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Restaurer depuis un fichier',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => _importData(context, storage),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Vos donnees
          Card(
            color: isDark ? AppColors.surfaceLight : AppColors.surfaceLightT,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.divider : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOS DONNEES',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DataRow(label: 'Favoris', value: '${storage.getFavorites().length}', isDark: isDark),
                  _DataRow(label: 'Versets maitrises', value: '${storage.totalMasteredAyahs}', isDark: isDark),
                  _DataRow(label: 'Notes', value: '${storage.getNotes().length}', isDark: isDark),
                  _DataRow(label: 'Signets', value: '${storage.getBookmarks().length}', isDark: isDark),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Reinitialiser
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _confirmReset(context, storage),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: Text(
                'Reinitialiser toutes les donnees',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, StorageService storage) async {
    try {
      final jsonData = storage.exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/al-hafiz-backup-$timestamp.json');
      await file.writeAsString(jsonData);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde',
        fileName: 'al-hafiz-backup-$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: file.readAsBytesSync(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savePath != null ? 'Sauvegarde exportee !' : 'Export annule'),
            backgroundColor: savePath != null ? AppColors.primary : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, StorageService storage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Importer des donnees', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text(
          'Cela remplacera toutes vos donnees actuelles. Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();
      await storage.importFromJson(jsonData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donnees restaurees avec succes !'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'import: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmReset(BuildContext context, StorageService storage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reinitialiser', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text(
          'Toutes vos donnees (favoris, notes, signets, progression) seront supprimees. Cette action est irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              storage.resetAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toutes les donnees ont ete supprimees'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Supprimer tout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DataRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
