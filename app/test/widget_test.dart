import 'package:flutter_test/flutter_test.dart';

import 'package:funghi_sicilia/models/species.dart';

void main() {
  test('Category.parse: codice sconosciuto => sconosciuta (prudenza)', () {
    expect(Category.parse('mortale'), Category.mortale);
    expect(Category.parse('boh'), Category.sconosciuta);
    expect(Category.parse(null).dangerous, isFalse);
  });

  test('tossiche, mortali, vietate e condizionate sono pericolose', () {
    for (final c in [
      Category.mortale,
      Category.tossicoGrave,
      Category.tossico,
      Category.vietato,
      Category.condizionato,
    ]) {
      expect(c.dangerous, isTrue, reason: c.code);
    }
    expect(Category.commestibileSicilia.dangerous, isFalse);
  });

  test('cleanWiki toglie immagini e link', () {
    const raw =
        'Image:Foo.JPG|didascalia\nTesto con [[Quercus|querce]] e [[castagno]].';
    expect(cleanWiki(raw), 'Testo con querce e castagno.');
  });

  test('Species.fromMap: consiglio mancante => NON RACCOGLIERE', () {
    final s = Species.fromMap({
      'key': 1,
      'nome_scientifico': 'X y',
      'categoria': 'x',
    }, const []);
    expect(s.advice, 'NON RACCOGLIERE');
    expect(s.doNotPick, isTrue);
  });

  test('nomi siciliani: lista di oggetti {nome, fonte}', () {
    final s = Species.fromMap({
      'key': 1,
      'nome_scientifico': 'X y',
      'categoria': 'tossico',
      'nomi_siciliani': '[{"nome": "russeddi", "fonte": "A"}, {"nome": "funci niuri", "fonte": "B"}]',
      'nomi_italiani': '["Tignosa"]',
    }, const []);
    expect(s.sicilianNames, ['russeddi', 'funci niuri']);
    expect(s.italianNames, ['Tignosa']);
  });
}
