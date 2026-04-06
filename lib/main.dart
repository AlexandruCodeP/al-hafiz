import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/reciter.dart';
import 'services/audio_service.dart';
import 'services/hifz_engine.dart';
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

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLightT,
          border: Border(
            top: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.2),
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.primaryLight),
              label: 'Quran',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.bookmark_rounded, color: AppColors.accent),
              label: 'Révisions',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}
