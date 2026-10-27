import 'package:flutter/material.dart';

import 'db/app_db.dart';
import 'ml/classifier.dart';
import 'ml/tflite_classifier.dart';
import 'screens/diary_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/glossary_screen.dart';
import 'screens/identify_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDb.open();
  Classifier classifier;
  try {
    classifier = await TfliteClassifier.load();
  } catch (_) {
    // Modello non disponibile: stub di prova (candidati fissi).
    classifier = StubClassifier(await db.stubCandidateIds());
  }
  runApp(FunghiApp(db: db, classifier: classifier));
}

class FunghiApp extends StatelessWidget {
  const FunghiApp({super.key, required this.db, required this.classifier});
  final AppDb db;
  final Classifier classifier;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Funghi Sicilia',
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: HomeShell(db: db, classifier: classifier),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.db, required this.classifier});
  final AppDb db;
  final Classifier classifier;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      IdentifyScreen(db: widget.db, classifier: widget.classifier),
      GlossaryScreen(db: widget.db),
      DiaryScreen(key: UniqueKey(), db: widget.db),
      const EmergencyScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Funghi Sicilia'), toolbarHeight: 56),
      body: Column(
        children: [
          const DisclaimerBanner(),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Identifica',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Glossario',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Diario',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency),
            label: 'Emergenza',
          ),
        ],
      ),
    );
  }
}
