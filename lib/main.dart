import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/reciter.dart';
import 'services/audio_service.dart';
import 'services/hifz_engine.dart';
import 'services/mushaf_repository.dart';
import 'services/storage_service.dart';
import 'screens/surah_list_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  final savedReciter = Reciter.getById(storageService.reciterId);

  runApp(AlHafizApp(
    storageService: storageService,
    initialReciter: savedReciter,
  ));
}

class AlHafizApp extends StatelessWidget {
  final StorageService storageService;
  final Reciter initialReciter;

  const AlHafizApp({
    super.key,
    required this.storageService,
    required this.initialReciter,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioService()..setReciter(initialReciter)),
        ChangeNotifierProxyProvider<AudioService, HifzEngine>(
          create: (ctx) => HifzEngine(ctx.read<AudioService>()),
          update: (_, audio, prev) => prev ?? HifzEngine(audio),
        ),
        ChangeNotifierProvider.value(value: storageService),
        // Le scan disque et le catalogue distant se font en tache de fond :
        // l'application demarre sans les attendre.
        ChangeNotifierProvider(
          create: (_) => MushafRepository()
            ..init(preferredPackId: storageService.mushafPackId),
        ),
      ],
      child: Consumer<StorageService>(
        builder: (context, storage, _) {
          return MaterialApp(
            title: 'Al-Hafiz',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: storage.themeMode,
            home: _EntryGate(storageService: storageService),
          );
        },
      ),
    );
  }
}

class _EntryGate extends StatelessWidget {
  final StorageService storageService;

  const _EntryGate({required this.storageService});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    if (!storage.onboardingComplete) {
      return OnboardingScreen(
        onComplete: () => storage.setOnboardingComplete(),
      );
    }
    return const _MainShell();
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? color : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const SurahListScreen(),
          FavoritesScreen(
            storageService: storage,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surface.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? AppColors.divider.withValues(alpha: 0.08)
                  : AppColors.divider.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book_rounded,
                  label: 'Quran',
                  color: AppColors.primaryLight,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.bookmark_outline_rounded,
                  selectedIcon: Icons.bookmark_rounded,
                  label: 'Révisions',
                  color: AppColors.accent,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: 'Réglages',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
