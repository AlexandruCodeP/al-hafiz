import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/reciter.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/hifz_engine.dart';
import 'services/storage_service.dart';
import 'screens/auth_screen.dart';
import 'screens/surah_list_screen.dart';
import 'screens/favorites_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://swtanfnprpddnsgzmsgn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN3dGFuZm5wcnBkZG5zZ3ptc2duIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzMDAyMDksImV4cCI6MjA5MDg3NjIwOX0.fvCUnbbIyrs_PCTl-kFktULpoCtXFKq80UNh42oEPKs',
  );

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  final authService = AuthService();

  final savedReciter = Reciter.getById(storageService.reciterId);

  runApp(AlHafizApp(
    storageService: storageService,
    authService: authService,
    initialReciter: savedReciter,
  ));
}

class AlHafizApp extends StatelessWidget {
  final StorageService storageService;
  final AuthService authService;
  final Reciter initialReciter;

  const AlHafizApp({
    super.key,
    required this.storageService,
    required this.authService,
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
        ChangeNotifierProvider.value(value: authService),
      ],
      child: Consumer<StorageService>(
        builder: (context, storage, _) {
          return MaterialApp(
            title: 'Al-Hafiz',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: storage.themeMode,
            home: _AuthGate(authService: authService),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  final AuthService authService;

  const _AuthGate({required this.authService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        if (authService.isLoggedIn) {
          return const _MainShell();
        }
        return AuthScreen(authService: authService);
      },
    );
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
          ],
        ),
      ),
    );
  }
}
