import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logic/notifications.dart';
import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'screens/setup/setup_wizard.dart';
import 'screens/subjects.dart';
import 'state/providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.instance.init();
  runApp(const ProviderScope(child: ProxyMateApp()));
}

/// Loads the save file and immediately replays the calendar, so the first frame
/// is already correct.
final bootstrapProvider = FutureProvider<void>(
  (ref) => ref.read(appProvider.notifier).hydrate(),
);

class ProxyMateApp extends StatelessWidget {
  const ProxyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProxyMate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  AppLifecycleListener? _lifecycle;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    // Catch-up runs on resume rather than in a background task. Android OEMs
    // kill background work aggressively, and silently-wrong attendance is the
    // exact failure this app exists to prevent.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(appProvider.notifier).refreshNow(),
    );

    // Keeps "upcoming" flipping to marked while the app sits open, and carries
    // it across midnight without a restart.
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.read(appProvider.notifier).refreshNow(),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootstrapProvider);
    final state = ref.watch(appProvider);

    return boot.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not start: $e'),
          ),
        ),
      ),
      data: (_) => state.isConfigured ? const _Shell() : const SetupWizard(),
    );
  }
}

/// Four tabs, ordered by how often they are opened: Home many times a week,
/// Subjects a few, History occasionally, More almost never.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    SubjectsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small),
            label: 'Subjects',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
