// Anteprime visive dell'interfaccia (PNG in ../data/screenshots/test_*.png).
// Esegui con:  VISUAL=1 flutter test test/visual_test.dart
// Non sostituisce la prova su telefono: serve a controllare layout, overflow e contrasto.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funghi_sicilia/ml/classifier.dart';
import 'package:funghi_sicilia/models/species.dart';
import 'package:funghi_sicilia/screens/emergency_screen.dart';
import 'package:funghi_sicilia/screens/glossary_screen.dart';
import 'package:funghi_sicilia/screens/identify_screen.dart';
import 'package:funghi_sicilia/screens/species_detail_screen.dart';
import 'package:funghi_sicilia/theme.dart';
import 'package:funghi_sicilia/widgets/common.dart';
import 'package:funghi_sicilia/db/app_db.dart';

const _sdkFonts =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
final _out = Directory('../data/screenshots');

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

class _FakeDb implements AppDb {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

List<Species> _sample() {
  final raw =
      jsonDecode(File('test/fixtures/sample.json').readAsStringSync()) as List;
  return [
    for (final e in raw)
      Species.fromMap((e['row'] as Map).cast<String, Object?>(), [
        for (final p in e['photos'] as List)
          SpeciesPhoto(
            asset: 'assets/${p['path']}',
            author: p['author'] as String?,
            license: p['license'] as String?,
            source: p['source'] as String?,
          ),
      ]),
  ];
}

void main() {
  final enabled = Platform.environment['VISUAL'] == '1';

  setUpAll(() async {
    if (!enabled) return;
    _out.createSync(recursive: true);
    await _loadFont('Fraunces', [
      'assets/fonts/Fraunces.ttf',
      'assets/fonts/Fraunces-Italic.ttf',
    ]);
    await _loadFont('Roboto', [
      '$_sdkFonts/Roboto-Regular.ttf',
      '$_sdkFonts/Roboto-Medium.ttf',
      '$_sdkFonts/Roboto-Bold.ttf',
      '$_sdkFonts/Roboto-Italic.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$_sdkFonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      });
    }
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${_out.path}/test_$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pumpApp(
    WidgetTester t,
    Widget child, {
    Brightness b = Brightness.light,
  }) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(b),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Funghi Sicilia')),
            body: Column(
              children: [
                const DisclaimerBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
    return key;
  }

  testWidgets('glossario', (t) async {
    final list = _sample();
    final key = await pumpApp(
      t,
      ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => SpeciesCard(species: list[i]),
      ),
    );
    await shot(t, key, 'glossario_1');
    await t.drag(find.byType(ListView), const Offset(0, -900));
    await shot(t, key, 'glossario_2');
    await t.drag(find.byType(ListView), const Offset(0, -900));
    await shot(t, key, 'glossario_3');
    await t.drag(find.byType(ListView), const Offset(0, -2500));
    await shot(t, key, 'glossario_4');
  }, skip: !enabled);

  testWidgets('glossario scuro', (t) async {
    final list = _sample();
    final key = await pumpApp(
      t,
      ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => SpeciesCard(species: list[i]),
      ),
      b: Brightness.dark,
    );
    await shot(t, key, 'glossario_scuro');
  }, skip: !enabled);

  for (final entry in {
    'mortale': 0,
    'commestibile': 1,
    'senza_dati': 7,
  }.entries) {
    testWidgets('scheda ${entry.key}', (t) async {
      final s = _sample()[entry.value];
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          home: RepaintBoundary(
            key: key,
            child: SpeciesDetailScreen(species: s),
          ),
        ),
      );
      await shot(t, key, 'scheda_${entry.key}_1');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await shot(t, key, 'scheda_${entry.key}_2');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await shot(t, key, 'scheda_${entry.key}_3');
    }, skip: !enabled);
  }

  testWidgets('identifica', (t) async {
    final key = await pumpApp(
      t,
      IdentifyScreen(db: _FakeDb(), classifier: StubClassifier(const [])),
    );
    await shot(t, key, 'identifica');
  }, skip: !enabled);

  testWidgets('emergenza', (t) async {
    final key = await pumpApp(t, const EmergencyScreen());
    await shot(t, key, 'emergenza');
  }, skip: !enabled);
}
