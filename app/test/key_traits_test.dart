import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funghi_sicilia/models/key_traits.dart';
import 'package:funghi_sicilia/models/species.dart';

Species _byName(String name) {
  final raw =
      jsonDecode(File('test/fixtures/sample.json').readAsStringSync()) as List;
  final e = raw.firstWhere(
    (e) => (e['row']['nome_scientifico'] as String).startsWith(name),
  );
  return Species.fromMap((e['row'] as Map).cast<String, Object?>(), const []);
}

void main() {
  test('categoria commestibile_sicilia si chiama "Commestibile"', () {
    expect(Category.commestibileSicilia.label, 'Commestibile');
  });

  test('Amanita phalloides: la volva è un carattere in evidenza', () {
    final t = _byName('Amanita phalloides').keyTraits;
    expect(t.where((x) => x.alert && x.value.contains('volva')), isNotEmpty);
    expect(
      t.any((x) => x.label == 'Sotto' && x.value.startsWith('lamelle')),
      isTrue,
    );
  });

  test('caratteri tradotti in italiano, mai "null" né inglese grezzo', () {
    for (final n in [
      'Amanita phalloides',
      'Cantharellus cibarius',
      'Pleurotus eryngii',
      'Armillaria mellea',
    ]) {
      for (final t in _byName(n).keyTraits) {
        expect(t.value, isNot(contains('null')));
        expect(
          t.value,
          isNot(
            matches(
              RegExp(r'\b(gills|pores|convex|white|brown|mycorrhizal)\b'),
            ),
          ),
        );
      }
    }
  });

  test(
    'specie senza dati strutturati: nessun carattere, frase di riserva o nulla',
    () {
      final s = _byName('Leccinum melaneum');
      expect(s.keyTraits, isEmpty);
      final b = s.fallbackBlurb;
      expect(b == null || b.isNotEmpty, isTrue);
    },
  );
}
